# PHASE2_REALTIME_POLISH.md

Implementation spec for Phase 2 of the Artisan Bidding Workflow: **Real-time updates, PDF generation, deadline management, and polish**.

> **Prerequisites:**
> - Phase 1 is fully implemented and working (see `ARTISAN_WORKFLOW_SPEC.md`)
> - Phase 1 bugs are fixed and UI is polished
> - App is deployed to: `https://opendevis-b28c4292efa7.herokuapp.com/`

Read `CLAUDE.md` and `ARTISAN_WORKFLOW_SPEC.md` first for full project context.

**No email in this phase.** All notifications are in-app only.

---

## 1. Real-time Tracking with Turbo Streams

When an artisan submits their price (via dashboard or magic link), the user's tracking page should update in real time without refreshing.

### 1.1 Broadcast on BiddingRequest update

In `app/models/bidding_request.rb`, add a callback:

```ruby
class BiddingRequest < ApplicationRecord
  # ... existing code ...

  after_update_commit :broadcast_status_change, if: :saved_change_to_status?

  private

  def broadcast_status_change
    broadcast_replace_to(
      "bidding_round_#{bidding_round_id}_requests",
      target: "bidding_request_#{id}",
      partial: "bidding_rounds/bidding_request_row",
      locals: { bidding_request: self }
    )

    broadcast_replace_to(
      "bidding_round_#{bidding_round_id}_requests",
      target: "bidding_progress",
      partial: "bidding_rounds/progress_bar",
      locals: { bidding_round: bidding_round }
    )
  end
end
```

### 1.2 Subscribe on the tracking page

In `app/views/bidding_rounds/show.html.erb`:

```erb
<%= turbo_stream_from "bidding_round_#{@bidding_round.id}_requests" %>
```

Each artisan row needs a matching target ID:

```erb
<div id="bidding_request_<%= request.id %>">
  <%= render "bidding_rounds/bidding_request_row", bidding_request: request %>
</div>
```

Progress bar:
```erb
<div id="bidding_progress">
  <%= render "bidding_rounds/progress_bar", bidding_round: @bidding_round %>
</div>
```

### 1.3 Trigger in-app notifications after artisan submission

In both `ArtisanPortalController#submit` and `ArtisanDashboard::RequestsController#submit_price`, after the artisan submits:

```ruby
# In-app notification
Notification.create!(
  user: @bidding_request.bidding_round.project.user,
  project: @bidding_request.bidding_round.project,
  kind: "artisan_responded",
  title: "#{@bidding_request.artisan.name} a répondu",
  body: "#{@bidding_request.work_category.name} — #{@bidding_request.price_total} € HT"
)

# Check if all resolved
check_all_resolved(@bidding_request.bidding_round)
```

```ruby
def check_all_resolved(bidding_round)
  active = bidding_round.bidding_requests.where.not(status: "replaced")
  return if active.where(status: "sent").exists?

  Notification.create!(
    user: bidding_round.project.user,
    project: bidding_round.project,
    kind: "all_responded",
    title: "Toutes les réponses reçues",
    body: "Vous pouvez maintenant consulter les recommandations."
  )
end
```

Extract this logic into a shared concern or service object to avoid duplication between the portal and dashboard controllers.

---

## 2. Deadline Job

Create `app/jobs/bidding_deadline_job.rb`:

```ruby
class BiddingDeadlineJob < ApplicationJob
  queue_as :default

  def perform(bidding_round_id)
    bidding_round = BiddingRound.find(bidding_round_id)
    return unless bidding_round.status.in?(%w[sent in_progress])

    # Mark all still-pending requests as expired (triggers Turbo Stream broadcast)
    bidding_round.bidding_requests
                 .where(status: "sent")
                 .find_each do |request|
      request.update!(status: "expired")
    end

    # In-app notification
    Notification.create!(
      user: bidding_round.project.user,
      project: bidding_round.project,
      kind: "all_responded",
      title: "Date limite atteinte",
      body: "Certains artisans n'ont pas répondu. Vous pouvez consulter les résultats disponibles."
    )
  end
end
```

**Schedule when bidding round is sent.** In the `send_requests` action (or equivalent in Phase 1):

```ruby
BiddingDeadlineJob.set(wait_until: @bidding_round.deadline).perform_later(@bidding_round.id)
```

---

## 3. PDF Generation for Final Quote

### 3.1 Gems

Add to `Gemfile`:

```ruby
gem "prawn"        # PDF generation
gem "prawn-table"  # Table support for Prawn
```

### 3.2 Service Object

Create `app/services/final_quote_pdf_generator.rb`:

```ruby
class FinalQuotePdfGenerator
  def initialize(bidding_round)
    @bidding_round = bidding_round
    @project = bidding_round.project
    @selections = bidding_round.final_selections.includes(bidding_request: [:artisan, :work_category])
  end

  def generate
    pdf = Prawn::Document.new(page_size: "A4", margin: [40, 40, 40, 40])

    # Header
    pdf.text "DEVIS FINALISÉ", size: 20, style: :bold
    pdf.move_down 10
    pdf.text "OpenDevis", size: 12, color: "9B9588"
    pdf.move_down 20

    # Project info
    pdf.text "Projet : #{@project.location_zip}", size: 14, style: :bold
    info = []
    info << "Surface : #{@project.total_surface_sqm&.to_i} m²" if @project.total_surface_sqm
    info << "Pièces : #{@project.room_count}" if @project.room_count
    standing_label = ["Éco", "Standard", "Premium"][@bidding_round.standing_level - 1]
    info << "Standing : #{standing_label}"
    pdf.text info.join(" · "), size: 10, color: "666666"
    pdf.move_down 20

    # Total
    total = @selections.sum { |s| s.bidding_request.price_total || 0 }
    pdf.text "Total artisans HT : #{format_price(total)} €", size: 16, style: :bold
    pdf.move_down 20

    # Category breakdown table
    pdf.text "Détail par catégorie", size: 14, style: :bold
    pdf.move_down 10

    table_data = [["Catégorie", "Artisan", "Note", "Prix HT"]]
    @selections.each do |selection|
      req = selection.bidding_request
      table_data << [
        req.work_category.name,
        "#{req.artisan.name} (#{req.artisan.company_name})",
        "#{req.artisan.rating}/5",
        "#{format_price(req.price_total)} €"
      ]
    end

    pdf.table(table_data, header: true, width: pdf.bounds.width) do |t|
      t.row(0).font_style = :bold
      t.row(0).background_color = "2C2A25"
      t.row(0).text_color = "FFFFFF"
      t.columns(3).align = :right
    end

    pdf.move_down 30

    # Artisan contact details
    pdf.text "Coordonnées des artisans", size: 14, style: :bold
    pdf.move_down 10

    @selections.each do |selection|
      artisan = selection.bidding_request.artisan
      pdf.text "#{artisan.name} — #{artisan.company_name}", style: :bold, size: 10
      pdf.text "Email : #{artisan.email}  ·  Tél : #{artisan.phone || 'N/A'}", size: 9, color: "666666"
      pdf.move_down 8
    end

    # Footer
    pdf.move_down 20
    pdf.text "Généré par OpenDevis le #{I18n.l(Time.current, format: :long)}", size: 8, color: "999999"

    pdf.render
  end

  private

  def format_price(amount)
    return "0,00" unless amount
    whole, decimal = format("%.2f", amount.to_f).split(".")
    "#{whole.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1 ')},#{decimal}"
  end
end
```

### 3.3 Controller action for PDF download

In `BiddingRoundsController`:

```ruby
def final_quote
  @bidding_round = @project.bidding_round
  # ... existing code ...

  respond_to do |format|
    format.html
    format.pdf do
      pdf_data = FinalQuotePdfGenerator.new(@bidding_round).generate
      send_data pdf_data,
        filename: "devis-#{@project.id}-#{Date.current}.pdf",
        type: "application/pdf",
        disposition: "attachment"
    end
  end
end
```

---

## 4. Artisan Replacement Flow

When an artisan hasn't responded and deadline hasn't passed, the user can replace them.

### 4.1 Controller action

In `BiddingRoundsController`:

```ruby
def replace_artisan
  @old_request = BiddingRequest.find(params[:bidding_request_id])
  @new_artisan = Artisan.find(params[:new_artisan_id])

  @old_request.update!(status: "replaced")

  new_request = @bidding_round.bidding_requests.create!(
    work_category: @old_request.work_category,
    artisan: @new_artisan,
    status: "sent",
    token: SecureRandom.urlsafe_base64(24),
    sent_at: Time.current
  )

  @old_request.update!(replaced_by: new_request)

  redirect_to project_bidding_round_path(@project),
    notice: "#{@new_artisan.name} a été contacté(e) en remplacement."
end
```

### 4.2 Route

Add to the bidding_round routes:

```ruby
resource :bidding_round, only: [:new, :create, :show] do
  # ... existing routes ...
  post :replace_artisan, on: :member
end
```

### 4.3 UI

On the tracking page, the "Remplacer" button opens a Turbo Frame modal or inline dropdown showing available replacement artisans (from the original pool of 10, minus already assigned). The new artisan's request immediately shows on their dashboard.

---

## 5. Notification Badge in Navbar

### 5.1 Stimulus controller

Create `app/javascript/controllers/notification_badge_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count"]

  connect() {
    this.poll()
    this.interval = setInterval(() => this.poll(), 30000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  async poll() {
    const response = await fetch("/notifications?format=json")
    const data = await response.json()
    const unread = data.unread_count

    if (unread > 0) {
      this.countTarget.textContent = unread
      this.countTarget.classList.remove("d-none")
    } else {
      this.countTarget.classList.add("d-none")
    }
  }
}
```

### 5.2 Navbar badge

In `app/views/shared/_navbar.html.erb`:

```erb
<div data-controller="notification-badge">
  <%= link_to notifications_path, class: "position-relative" do %>
    🔔
    <span class="badge bg-danger rounded-pill position-absolute top-0 start-100 translate-middle d-none"
          data-notification-badge-target="count"
          style="font-size: 0.65rem;">
    </span>
  <% end %>
</div>
```

---

## 6. Summary of New/Changed Files

```
app/services/final_quote_pdf_generator.rb                # NEW
app/jobs/bidding_deadline_job.rb                          # NEW
app/models/bidding_request.rb                             # UPDATE (+ Turbo Stream broadcast)
app/views/bidding_rounds/_bidding_request_row.html.erb    # NEW partial
app/views/bidding_rounds/_progress_bar.html.erb           # NEW partial
app/views/bidding_rounds/show.html.erb                    # UPDATE (+ turbo_stream_from)
app/javascript/controllers/notification_badge_controller.js  # NEW
app/views/shared/_navbar.html.erb                         # UPDATE (+ notification badge)
app/controllers/artisan_portal_controller.rb              # UPDATE (+ notification on submit)
app/controllers/artisan_dashboard/requests_controller.rb  # UPDATE (+ notification on submit)
app/controllers/bidding_rounds_controller.rb              # UPDATE (+ replace_artisan, PDF)
Gemfile                                                   # + prawn, prawn-table
```

No new migrations needed — Phase 2 uses the same models from Phase 1.