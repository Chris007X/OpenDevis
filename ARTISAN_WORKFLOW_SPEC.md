# ARTISAN_WORKFLOW_SPEC.md

This document specifies a new feature for OpenDevis: the **Artisan Bidding Workflow**. After a project quote is generated via the existing wizard, the user can dispatch selected categories to artisans for real pricing. This file is intended as a complete implementation guide for Claude Code.

> **Read CLAUDE.md first** — it describes the existing codebase, models, routes, and conventions. This spec builds on top of that foundation.

---

## 1. Feature Overview

### High-level flow

```
Existing wizard (Steps 1-4)
    ↓
Quote generated (3 standing levels: Éco/Standard/Premium)
    ↓
User picks ONE standing level → this is the "selected quote"
    ↓
User selects which categories to send to artisans
    ↓
For each category, user picks 3 artisans from a list of 10 (filtered by postcode)
    ↓
User sets a response deadline (date/time)
    ↓
Each selected artisan sees the new request on their Artisan Dashboard
    ↓
Artisan responds via:
  (a) Artisan Dashboard (logged in), OR
  (b) Magic link (token-based URL, shareable)
    ↓
Artisan provides: a single total price for the category
    ↓
Once all responses are in (or deadline reached):
  → AI recommends best-value artisan per category (price + rating)
  → User confirms/overrides selections
    ↓
Final consolidated quote:
  → Displayed on platform (sum of selected artisan prices per category)
  → Downloadable as PDF devis
```

### Key constraints

- **One bidding round per project.** User picks one standing level, sends to artisans once. No re-runs.
- **Max 3 artisans per category.** User selects them from a displayed list of 10.
- **User can replace** an unresponsive artisan before the deadline (send to a different one from the remaining pool).
- Artisan response is **just a total price** for the category — no line-by-line breakdown.

---

## 2. New Models

### 2.1 `Artisan`

Represents a professional who can bid on work categories. **Artisans have accounts** (Devise) and log in to see their requests on a dashboard.

```ruby
# Fields:
#   name                   :string, not null
#   email                  :string, not null, unique
#   encrypted_password     :string, not null       # Devise
#   phone                  :string
#   company_name           :string
#   postcode               :string, not null       # coverage area
#   rating                 :decimal(3,2)           # average rating, 0.00–5.00
#   certifications         :text                   # comma-separated or JSON array
#   portfolio_url          :string
#   active                 :boolean, default: true
#   reset_password_token   :string                 # Devise
#   reset_password_sent_at :datetime               # Devise
#   remember_created_at    :datetime               # Devise
#
# Associations:
#   has_many :artisan_categories
#   has_many :work_categories, through: :artisan_categories
#   has_many :bidding_requests
```

**Authentication:** Artisans use Devise with a **separate scope** from users. Separate login pages (`/artisans/sign_in` vs `/users/sign_in`), separate sessions, separate models.

```ruby
# app/models/artisan.rb
class Artisan < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :artisan_categories
  has_many :work_categories, through: :artisan_categories
  has_many :bidding_requests
  # ...
end
```

**Postcode matching logic:** An artisan with postcode `"75010"` can serve projects with `location_zip` starting with the same 2-digit department (`"75"`). Implement as a scope: `Artisan.for_postcode(zip)` that matches on the first 2 characters. This can be refined later (radius, multi-postcode, etc.).

### 2.2 `ArtisanCategory` (join table)

```ruby
# Fields:
#   artisan_id        :bigint, not null, FK
#   work_category_id  :bigint, not null, FK
#
# Unique index on [artisan_id, work_category_id]
```

### 2.3 `BiddingRound`

One per project. Tracks the overall artisan bidding process.

```ruby
# Fields:
#   project_id         :bigint, not null, FK, unique (one round per project)
#   standing_level     :integer, not null     # 1=Éco, 2=Standard, 3=Premium — locked at creation
#   status             :string, not null      # enum: draft, sent, in_progress, completed, cancelled
#   deadline           :datetime, not null    # user-set deadline for artisan responses
#   created_at         :datetime
#   updated_at         :datetime
#
# Associations:
#   belongs_to :project
#   has_many   :bidding_requests
```

**Statuses:**
- `draft` — user is selecting categories/artisans, not yet sent
- `sent` — requests dispatched to artisans, waiting for responses
- `in_progress` — at least one artisan has responded
- `completed` — user has confirmed final selections
- `cancelled` — user cancelled the round

### 2.4 `BiddingRequest`

One per (category × artisan) pair. Tracks each individual request sent to an artisan.

```ruby
# Fields:
#   bidding_round_id   :bigint, not null, FK
#   work_category_id   :bigint, not null, FK
#   artisan_id         :bigint, not null, FK
#   status             :string, not null      # enum: pending, sent, responded, declined, replaced, expired
#   price_total        :decimal(10,2)         # artisan's quoted total price (null until responded)
#   responded_at       :datetime
#   token              :string, not null      # unique token for magic-link portal access
#   sent_at            :datetime
#   replaced_by_id     :bigint, FK            # self-referential: points to the replacement BiddingRequest
#   created_at         :datetime
#   updated_at         :datetime
#
# Unique index on [bidding_round_id, work_category_id, artisan_id]
# Unique index on [token]
#
# Associations:
#   belongs_to :bidding_round
#   belongs_to :work_category
#   belongs_to :artisan
#   belongs_to :replaced_by, class_name: "BiddingRequest", optional: true
```

**Statuses:**
- `pending` — created but email not yet sent
- `sent` — request visible to artisan on their dashboard
- `responded` — artisan has submitted a price
- `declined` — artisan explicitly declined
- `replaced` — user replaced this artisan with another (set `replaced_by_id`)
- `expired` — deadline passed without response

### 2.5 `FinalSelection`

Records the user's confirmed artisan choice per category after AI recommendation.

```ruby
# Fields:
#   bidding_round_id   :bigint, not null, FK
#   work_category_id   :bigint, not null, FK
#   bidding_request_id :bigint, not null, FK  # the winning BiddingRequest
#   ai_recommended     :boolean, default: false  # true if this was the AI's top pick
#   confirmed_at       :datetime
#
# Unique index on [bidding_round_id, work_category_id]
```

### 2.6 `Notification` (in-app)

```ruby
# Fields:
#   user_id            :bigint, not null, FK
#   project_id         :bigint, FK            # optional, for linking
#   kind               :string, not null      # "artisan_responded", "all_responded", "final_quote_ready"
#   title              :string, not null
#   body               :text
#   read               :boolean, default: false
#   created_at         :datetime
```

---

## 3. Updated Model Relationships

```
User
└── has_many :projects
│   └── has_one  :bidding_round
│       └── has_many :bidding_requests
│       └── has_many :final_selections
└── has_many :notifications

Artisan
├── has_many :artisan_categories
├── has_many :work_categories, through: :artisan_categories
└── has_many :bidding_requests

WorkCategory
├── has_many :artisan_categories
├── has_many :artisans, through: :artisan_categories
└── (existing: has_many :materials, has_many :work_items)
```

---

## 4. Routes

```ruby
# Add to config/routes.rb

# Artisan authentication (separate Devise scope):
devise_for :artisans

resources :projects do
  # Existing:
  resources :rooms, only: [:index, :new, :create]
  resources :documents, only: [:index, :new, :create]

  # NEW — Artisan Bidding (user-facing):
  resource :bidding_round, only: [:new, :create, :show] do
    post   :send_requests,       on: :member   # create requests + mark as sent
    get    :select_artisans,     on: :member   # step 2: pick artisans per category
    patch  :update_artisans,     on: :member   # save artisan selections
    get    :review_responses,    on: :member   # view artisan responses + AI recommendation
    post   :confirm_selections,  on: :member   # confirm final picks
    get    :final_quote,         on: :member   # view consolidated quote
  end
end

# Artisan-facing portal (token-based, no auth required):
get  "artisan/respond/:token", to: "artisan_portal#show",   as: :artisan_portal
post "artisan/respond/:token", to: "artisan_portal#submit",  as: :artisan_portal_submit

# Artisan dashboard (requires artisan login):
namespace :artisan_dashboard do
  root to: "home#index"                          # main dashboard
  resources :requests, only: [:index, :show] do  # list + detail of bidding requests
    post :submit_price, on: :member              # submit price from dashboard
    post :decline,      on: :member              # decline from dashboard
  end
  resource :profile, only: [:show, :edit, :update]
end

# Notification badge (for users):
resources :notifications, only: [:index] do
  post :mark_read, on: :member
end
```

---

## 5. User Flow (extended)

Extends the flow from `docs/wireframe-spec.md`:

```
=== USER (HOMEOWNER) FLOW ===

Landing Page → Sign Up / Login
    ↓
Dashboard (projects#index)
    ↓
[+ Nouveau projet] → Wizard Step 1 → Step 2 → Step 3 → Step 4
    → [Générer l'estimation]
    ↓
Results Page (projects#show)
    ↓                              ↓
[Click room] → Room Detail    [📨 Envoyer aux artisans]
                                   ↓
                              Bidding Step 1: Select categories + deadline
                                   ↓
                              Bidding Step 2: Pick 3 artisans per category
                                   ↓
                              [Envoyer les demandes] → requests created
                                   ↓
                              Tracking Page (monitor responses)
                                   ↓
                              Review & Confirm (AI recommendations)
                                   ↓
                              Final Consolidated Quote (view + PDF)

=== ARTISAN FLOW ===

Artisan Login (/artisans/sign_in)
    ↓
Artisan Dashboard (list of pending/past requests)
    ↓
[Click request] → Request Detail (project summary + price form)
    ↓
[Submit price] or [Decline]

OR (alternative access):

Magic Link (/artisan/respond/:token) → Response Form (no login needed)
```

---

## 6. Screen Details — Artisan Bidding

All views use Bootstrap 5.3 + Hotwire (Turbo Frames/Streams + Stimulus). Match the existing design system from CLAUDE.md and `docs/wireframe-spec.md` (colors, cards, typography).

### 6.1 Trigger: CTA on Results Page (`projects#show`)

Add a new section on the existing results page, below the category cards and above the rooms section.

**When no bidding round exists (`project.bidding_round.nil?`):**

```
┌─────────────────────────────────────────────────┐
│                                                  │
│  ... existing summary bar + category cards ...   │
│                                                  │
│  ┌──────────────────────────────────────────────┐│
│  │  💬 Obtenez des devis réels d'artisans       ││
│  │                                              ││
│  │  Envoyez votre estimation à des artisans     ││
│  │  qualifiés de votre secteur pour obtenir     ││
│  │  des prix fermes.                            ││
│  │                                              ││
│  │            [📨 Envoyer aux artisans]          ││  ← btn-dark-od
│  └──────────────────────────────────────────────┘│
│                                                  │
│  ... existing rooms section ...                  │
│                                                  │
└─────────────────────────────────────────────────┘
```

**When bidding round exists — status banner replaces the CTA:**

```
┌──────────────────────────────────────────────────┐
│  📨 Demandes envoyées                            │
│  4/6 réponses reçues · Deadline: 17/03 à 18:00  │
│                                                  │
│  [Voir le suivi →]                               │  ← link to tracking page
└──────────────────────────────────────────────────┘
```

Or if completed:

```
┌──────────────────────────────────────────────────┐
│  ✅ Devis finalisé                               │
│  Total artisans: 38 750 €                        │
│                                                  │
│  [Voir le devis finalisé →]                      │  ← link to final_quote
└──────────────────────────────────────────────────┘
```

---

### 6.2 Bidding Step 1 — Select Categories + Deadline (`bidding_rounds#new`)

**Route:** `GET /projects/:project_id/bidding_round/new?standing=2`

**Purpose:** User locks a standing level, selects which categories to send, sets a deadline.

```
┌─────────────────────────────────────────────────┐
│  ← Retour au projet                             │
│                                                  │
│  Demander des devis artisans                     │
│                                                  │
│  ┌──────────────────────────────────────────────┐│
│  │ Niveau sélectionné : Standard                ││
│  │ Estimation initiale : 34 350 € HT           ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  Catégories à envoyer                            │
│  Sélectionnez les catégories pour lesquelles     │
│  vous souhaitez recevoir des devis artisans.     │
│                                                  │
│  ┌────────┐  ┌────────┐  ┌────────┐            │
│  │☑ 🔧   │  │☑ ⚡   │  │☐ 🖌️   │            │
│  │Plomber.│  │Électr. │  │Peinture│            │
│  │12 posts│  │18 posts│  │9 postes│            │
│  │8 450 € │  │6 200 € │  │4 800 € │            │
│  └────────┘  └────────┘  └────────┘            │
│                                                  │
│  ┌────────┐  ┌────────┐  ┌────────┐            │
│  │☐ 🧱   │  │☐ ◻️   │  │☐ 🌡️   │            │
│  │Isolat. │  │Carrel. │  │Chauff. │            │
│  └────────┘  └────────┘  └────────┘            │
│                                                  │
│  Date limite de réponse                          │
│  [  17/03/2026  ] à [  18:00  ]                 │
│  Les artisans auront 7 jours pour répondre.      │
│                                                  │
│  ← Retour             [Choisir les artisans →]  │
└─────────────────────────────────────────────────┘
```

**Data:**
- Standing level is passed as URL param, locked at creation (not changeable here)
- Only categories that have `work_items` at the chosen `standing_level` are shown
- Each category card is a checkbox toggle (reuse `cat-card` styling + checkbox overlay)
- Card shows: icon, name, item count, subtotal HT (from existing `@categories_data`)
- Deadline: date + time picker. Default: 7 days from now. Minimum: 24h from now.
- "Choisir les artisans →" is disabled until ≥ 1 category selected + valid deadline

**Saves:** `POST /projects/:project_id/bidding_round` → creates `BiddingRound` (status: `draft`, standing_level, deadline). Store selected category IDs in session or as hidden params for next step.

---

### 6.3 Bidding Step 2 — Select Artisans (`bidding_rounds#select_artisans`)

**Route:** `GET /projects/:project_id/bidding_round/select_artisans`

**Purpose:** For each selected category, user picks exactly 3 artisans from a list of 10.

```
┌─────────────────────────────────────────────────┐
│  ← Retour                                       │
│                                                  │
│  Choisir vos artisans                            │
│  Sélectionnez 3 artisans par catégorie.          │
│                                                  │
│  ▼ 🔧 Plomberie                    2/3 choisis  │ ← accordion, open
│  ┌──────────────────────────────────────────────┐│
│  │ ☑ Jean Dupont — Dupont Plomberie             ││
│  │   ★★★★☆ 4.5  ·  [RGE] [Qualibat]           ││
│  │   🔗 Portfolio                               ││
│  ├──────────────────────────────────────────────┤│
│  │ ☑ Marie Martin — Martin & Fils               ││
│  │   ★★★★★ 4.8  ·  [RGE] [CAPEB]              ││
│  ├──────────────────────────────────────────────┤│
│  │ ☐ Pierre Durand — Durand SAS                 ││
│  │   ★★★☆☆ 3.4  ·  [Qualibat]                  ││
│  ├──────────────────────────────────────────────┤│
│  │ ☐ Luc Bernard — Bernard Plomberie            ││
│  │   ★★★★☆ 4.1  ·  [RGE] [QualiPV]            ││
│  ├──────────────────────────────────────────────┤│
│  │ ... (up to 10 artisans listed)               ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  ▶ ⚡ Électricité                   3/3 choisis ✓│ ← accordion, collapsed
│                                                  │
│  ⚠️ Minimum 3 artisans par catégorie requis.     │ ← warning if < 3 available
│                                                  │
│  ← Retour            [Envoyer les demandes 📨]  │ ← disabled until all 3/3
└─────────────────────────────────────────────────┘
```

**Data:**
- One accordion section per selected category
- Artisans filtered by: `Artisan.for_postcode(project.location_zip)` + matching `work_category`
- Display up to 10 per category, sorted by rating (descending)
- Each artisan row: checkbox, name, company, star rating, certifications (as chips), portfolio link
- Counter per category: "2/3 choisis" (gray) or "3/3 choisis ✓" (green)
- Stimulus controller `artisan-select`: enforces max 3 selected per category, disables remaining checkboxes when 3 reached
- If < 3 artisans available: show warning, allow sending with fewer
- "Envoyer les demandes" button: disabled until every category has exactly 3 (or max available if < 3)

**Saves:** `PATCH /projects/:project_id/bidding_round/update_artisans` → creates `BiddingRequest` records (status: `pending`, token auto-generated). Then immediately triggers `POST send_requests`.

---

### 6.4 Dispatch: Send Requests (`bidding_rounds#send_requests`)

**Route:** `POST /projects/:project_id/bidding_round/send_requests`

Not a visible screen — this is a POST action:
1. For each `BiddingRequest` in `pending` status:
   - Generate a unique `token` (SecureRandom.urlsafe_base64)
   - Set status → `sent`, set `sent_at`
2. Set `BiddingRound.status` → `sent`
3. Schedule `BiddingDeadlineJob` at `@bidding_round.deadline`
4. Redirect to tracking page: `project_bidding_round_path(@project)`

The requests are now visible on each artisan's dashboard. No email is sent.

---

### 6.5 Tracking Page (`bidding_rounds#show`)

**Route:** `GET /projects/:project_id/bidding_round`

**Purpose:** User monitors artisan responses. Live-updated.

```
┌─────────────────────────────────────────────────┐
│  ← Retour au projet                             │
│                                                  │
│  Suivi des demandes                              │
│  ⏱️ Date limite : 17 mars 2026 à 18:00          │
│     (dans 5 jours 14 heures)                    │
│                                                  │
│  ┌──────────────────────────────────────────────┐│
│  │  4/6 réponses reçues            ████████░░░  ││ ← progress bar
│  └──────────────────────────────────────────────┘│
│                                                  │
│  🔧 Plomberie                                    │
│  ┌──────────────────────────────────────────────┐│
│  │ Jean Dupont    ★4.5  │  ✅ Répondu  │4 200 € ││
│  ├──────────────────────────────────────────────┤│
│  │ Marie Martin   ★4.8  │  ✅ Répondu  │3 800 € ││
│  ├──────────────────────────────────────────────┤│
│  │ Luc Bernard    ★4.1  │  ⏳ En attente│  —    ││
│  │                                  [Remplacer] ││ ← ghost btn
│  └──────────────────────────────────────────────┘│
│                                                  │
│  ⚡ Électricité                                   │
│  ┌──────────────────────────────────────────────┐│
│  │ Sophie Leroy   ★4.6  │  ✅ Répondu  │5 900 € ││
│  ├──────────────────────────────────────────────┤│
│  │ Paul Moreau    ★3.9  │  ✅ Répondu  │6 450 € ││
│  ├──────────────────────────────────────────────┤│
│  │ Claire Petit   ★4.3  │  ❌ Décliné  │  —    ││
│  │                                  [Remplacer] ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│              [Voir les recommandations →]         │ ← appears when all
│                                                  │    responded or deadline
└─────────────────────────────────────────────────┘
```

**Status badges (pill style, matching existing design):**
- ⏳ En attente — warm gray (`badge-brouillon` style)
- ✅ Répondu — soft green (`badge-en-cours` style)
- ❌ Décliné — soft red
- ⏰ Expiré — soft orange

**"Remplacer" button:**
- Only visible if `BiddingRequest.status` is `sent` (not yet responded) AND deadline not passed
- Opens a small modal or inline dropdown showing remaining artisans (from the pool of 10, minus already selected/used)
- Selecting a replacement: marks old request as `replaced`, creates a new `BiddingRequest` (immediately visible on the new artisan's dashboard)

**Real-time updates:**
- Phase 1: Stimulus controller `tracking-poll` — polls `bidding_rounds#show` via Turbo Frame every 30 seconds
- Phase 2: Replace with Turbo Streams (ActionCable broadcast on `BiddingRequest` update)

**"Voir les recommandations" CTA:**
- Hidden until: all active (non-replaced) `BiddingRequest` records are in a terminal state (`responded`, `declined`, `expired`) OR deadline has passed
- When deadline passes: a `BiddingDeadlineJob` marks all remaining `sent` requests as `expired`

---

### 6.6 Review & Confirm (`bidding_rounds#review_responses`)

**Route:** `GET /projects/:project_id/bidding_round/review_responses`

**Purpose:** AI recommends best-value artisan per category. User confirms or overrides.

```
┌─────────────────────────────────────────────────┐
│  ← Retour au suivi                              │
│                                                  │
│  Recommandations                                 │
│  L'IA a analysé les devis reçus et vous          │
│  recommande les meilleurs rapports qualité-prix. │
│                                                  │
│  🔧 Plomberie                                    │
│  ┌──────────────┐  ┌──────────────┐             │
│  │ ● Marie      │  │ ○ Jean       │             │
│  │   Martin     │  │   Dupont     │             │
│  │ ★★★★★ 4.8   │  │ ★★★★☆ 4.5   │             │
│  │ 3 800 € HT  │  │ 4 200 € HT  │             │
│  │              │  │              │             │
│  │ ✨ Recommandé │  │              │             │
│  │ Meilleur prix│  │              │             │
│  │ + note élevée│  │              │             │
│  └──────────────┘  └──────────────┘             │
│  (Luc Bernard — pas de réponse)                  │
│                                                  │
│  ⚡ Électricité                                   │
│  ┌──────────────┐  ┌──────────────┐             │
│  │ ● Sophie     │  │ ○ Paul       │             │
│  │   Leroy      │  │   Moreau     │             │
│  │ ★★★★☆ 4.6   │  │ ★★★☆☆ 3.9   │             │
│  │ 5 900 € HT  │  │ 6 450 € HT  │             │
│  │              │  │              │             │
│  │ ✨ Recommandé │  │              │             │
│  └──────────────┘  └──────────────┘             │
│  (Claire Petit — décliné)                        │
│                                                  │
│  ┌──────────────────────────────────────────────┐│
│  │  Total sélectionné :  9 700 € HT            ││
│  │  (Plomberie 3 800 € + Électricité 5 900 €)  ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  ← Retour          [Confirmer et finaliser ✨]   │
└─────────────────────────────────────────────────┘
```

**Data & behavior:**
- Per category: show only artisans who responded (exclude declined/expired/replaced)
- Each artisan displayed as a selectable card (radio button behavior — one per category)
- AI pre-selects the recommended artisan (radio pre-checked)
- **AI recommendation badge:** "✨ Recommandé" + short reason (e.g. "Meilleur prix + note élevée")
- User can override by clicking a different card
- Non-responders listed as dimmed text below the cards: "(Name — pas de réponse)" or "(Name — décliné)"
- Total section at bottom: dynamic sum of all currently selected artisan prices (updates via Stimulus when user changes a selection)
- If NO artisan responded for a category: show warning "Aucune réponse reçue pour cette catégorie" + option to keep the original estimate or remove

**AI recommendation logic (pure Ruby, no LLM):**
```
score = 0.6 × price_score + 0.4 × rating_score
where:
  price_score  = 1 - (price - min) / (max - min)    → 1.0 = cheapest
  rating_score = artisan.rating / 5.0                → 1.0 = best rated
  (if only one responder: price_score = 1.0)
Pick artisan with highest score.
```

**Saves:** `POST /projects/:project_id/bidding_round/confirm_selections` → creates `FinalSelection` per category, sets `BiddingRound.status` → `completed`. Enqueues `GenerateFinalQuotePdfJob`.

---

### 6.7 Final Quote (`bidding_rounds#final_quote`)

**Route:** `GET /projects/:project_id/bidding_round/final_quote`

**Purpose:** Display consolidated quote with per-category artisan breakdown. Download as PDF.

```
┌─────────────────────────────────────────────────┐
│  ← Retour au projet                             │
│                                                  │
│  Devis finalisé                                  │
│  Appt 75001 · 78 m² · 5 pièces                  │
│                                                  │
│  ┌──────────────────────────────────────────────┐│
│  │                                              ││
│  │          Total artisans HT                   ││
│  │            9 700 €                           ││
│  │                                              ││
│  │  vs estimation initiale : 14 650 € HT       ││
│  │  (Plomberie 8 450 € + Électricité 6 200 €)  ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  Détail par catégorie                            │
│  ┌──────────────────────────────────────────────┐│
│  │ 🔧 Plomberie                                 ││
│  │ Artisan : Marie Martin  ★4.8                 ││
│  │ Prix artisan :              3 800 € HT      ││
│  │ Estimation initiale :       8 450 € HT      ││
│  ├──────────────────────────────────────────────┤│
│  │ ⚡ Électricité                                ││
│  │ Artisan : Sophie Leroy  ★4.6                 ││
│  │ Prix artisan :              5 900 € HT      ││
│  │ Estimation initiale :       6 200 € HT      ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  [Télécharger le PDF]                            │
│                                                  │
│  Coordonnées des artisans                        │
│  ┌──────────────────────────────────────────────┐│
│  │ Marie Martin — Dupont Plomberie              ││
│  │ 📧 marie.martin@email.com  📞 06 12 34 56   ││
│  ├──────────────────────────────────────────────┤│
│  │ Sophie Leroy — Leroy Électricité             ││
│  │ 📧 sophie.leroy@email.com  📞 06 98 76 54   ││
│  └──────────────────────────────────────────────┘│
└─────────────────────────────────────────────────┘
```

**Data:**
- Total = sum of all `FinalSelection` artisan prices
- Comparison with initial estimate: sum of `work_items` subtotals at the chosen `standing_level` for the sent categories
- Per-category row: category icon + name, selected artisan name + rating, artisan price, original estimate price
- Artisan contact details section: name, company, email, phone for each selected artisan
- "Télécharger le PDF" → `GET` that returns a generated PDF (via `GenerateFinalQuotePdfJob` or on-demand)

---

## 7. Screen Details — Artisan Side

Artisans have **two ways** to interact with the platform:
1. **Artisan Dashboard** (requires login) — see all requests, respond, manage profile
2. **Magic Link Portal** (no login) — respond to a specific request via token URL

### 7.1 Artisan Login

**Route:** `GET /artisans/sign_in` (Devise)

Standard Devise login page, styled to match OpenDevis design system. Include "Créer un compte" link.

### 7.2 Artisan Dashboard — Home (`artisan_dashboard/home#index`)

**Route:** `GET /artisan_dashboard`

**Purpose:** Artisan sees all their pending and past requests at a glance.

```
┌─────────────────────────────────────────────────┐
│  OPENDEVIS    Tableau de bord         J. Dupont │ ← artisan navbar
├─────────────────────────────────────────────────┤
│                                                  │
│  Bonjour Jean 👋                                │
│                                                  │
│  Demandes en attente (2)                         │
│  ┌──────────────────────────────────────────────┐│
│  │ 🔧 Plomberie · 75001 · 78 m² · Standard     ││
│  │ Réf: 8 450 € HT  ·  ⏱️ Deadline: 17/03     ││
│  │                              [Répondre →]    ││
│  ├──────────────────────────────────────────────┤│
│  │ 🔧 Plomberie · 92100 · 120 m² · Premium     ││
│  │ Réf: 12 300 € HT  ·  ⏱️ Deadline: 20/03    ││
│  │                              [Répondre →]    ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  Demandes passées (3)                            │
│  ┌──────────────────────────────────────────────┐│
│  │ ⚡ Électricité · 75011 · Standard            ││
│  │ Votre prix: 5 900 € HT  ·  ✅ Répondu       ││
│  ├──────────────────────────────────────────────┤│
│  │ 🔧 Plomberie · 94300 · Éco                   ││
│  │ ❌ Décliné                                    ││
│  ├──────────────────────────────────────────────┤│
│  │ 🧱 Isolation · 75015 · Standard              ││
│  │ ⏰ Expiré (pas de réponse)                    ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  [Mon profil]                                    │
└─────────────────────────────────────────────────┘
```

**Data:**
- Split requests into "en attente" (status: `sent`) and "passées" (status: `responded`, `declined`, `expired`, `replaced`)
- Each row: category icon + name, project postcode, surface, standing level
- Pending rows: reference estimate, deadline, "Répondre →" link
- Past rows: submitted price or status
- Sorted: pending by deadline (soonest first), past by `responded_at` (most recent first)

**Important:** The artisan navbar is different from the user navbar. Show artisan name, link to dashboard, link to profile, logout.

### 7.3 Artisan Dashboard — Request Detail (`artisan_dashboard/requests#show`)

**Route:** `GET /artisan_dashboard/requests/:id`

**Purpose:** Full detail of a request + response form (same content as magic link page, but within the logged-in dashboard layout).

```
┌─────────────────────────────────────────────────┐
│  OPENDEVIS    Tableau de bord         J. Dupont │
├─────────────────────────────────────────────────┤
│                                                  │
│  ← Retour au tableau de bord                    │
│                                                  │
│  Demande de devis                                │
│                                                  │
│  ┌──────────────────────────────────────────────┐│
│  │  📋 Résumé du projet                         ││
│  │                                              ││
│  │  Catégorie :     Plomberie 🔧                ││
│  │  Surface :       78 m²                       ││
│  │  Pièces :        5                           ││
│  │  Standing :      Standard                    ││
│  │  Localisation :  75001                       ││
│  │                                              ││
│  │  Estimation de référence : 8 450 € HT       ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  Votre proposition                               │
│                                                  │
│  Prix total HT (€)                               │
│  ┌──────────────────────────┐                    │
│  │                          │                    │
│  └──────────────────────────┘                    │
│                                                  │
│  Commentaire (facultatif)                        │
│  ┌──────────────────────────────────────────────┐│
│  │                                              ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  [Envoyer mon devis]       [Décliner]           │
│                                                  │
│  📅 Date limite : 17/03/2026 à 18:00            │
└─────────────────────────────────────────────────┘
```

This is the same form as the magic link portal (§7.5) but rendered inside the artisan dashboard layout. The controller should share logic (extract to a concern or service).

### 7.4 Artisan Profile (`artisan_dashboard/profiles#edit`)

**Route:** `GET /artisan_dashboard/profile/edit`

```
┌─────────────────────────────────────────────────┐
│  OPENDEVIS    Tableau de bord         J. Dupont │
├─────────────────────────────────────────────────┤
│                                                  │
│  Mon profil                                      │
│                                                  │
│  Nom             [Jean Dupont          ]         │
│  Entreprise      [Dupont Plomberie     ]         │
│  Email           [jean.dupont@email.com]         │
│  Téléphone       [06 12 34 56 78       ]         │
│  Code postal     [75010               ]          │
│                                                  │
│  Certifications                                  │
│  [RGE] [Qualibat] [+ Ajouter]                   │
│                                                  │
│  Portfolio URL                                   │
│  [https://...                          ]         │
│                                                  │
│  [Enregistrer]                                   │
└─────────────────────────────────────────────────┘
```

### 7.5 Magic Link Portal (no login required)

**Route:** `GET /artisan/respond/:token`

This is the **alternative access** for artisans. They can respond to a specific request without logging in — useful for quick access. The token identifies the `BiddingRequest`.

**Before responding:**

```
┌─────────────────────────────────────────────────┐
│  OPENDEVIS                                       │
│                                                  │
│  Demande de devis                                │
│                                                  │
│  ┌──────────────────────────────────────────────┐│
│  │  📋 Résumé du projet                         ││
│  │                                              ││
│  │  Catégorie :     Plomberie 🔧                ││
│  │  Surface :       78 m²                       ││
│  │  Pièces :        5                           ││
│  │  Standing :      Standard                    ││
│  │  Localisation :  75001                       ││
│  │                                              ││
│  │  Estimation de référence : 8 450 € HT       ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  Votre proposition                               │
│                                                  │
│  Prix total HT (€)                               │
│  ┌──────────────────────────┐                    │
│  │                          │                    │
│  └──────────────────────────┘                    │
│                                                  │
│  Commentaire (facultatif)                        │
│  ┌──────────────────────────────────────────────┐│
│  │                                              ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  [Envoyer mon devis]       [Décliner]           │
│   ↑ btn-dark-od             ↑ btn-ghost-od       │
│                                                  │
│  📅 Date limite : 17/03/2026 à 18:00            │
│                                                  │
│  💡 Vous avez un compte ?                        │
│     Connectez-vous pour gérer toutes vos         │
│     demandes. [Se connecter →]                   │
└─────────────────────────────────────────────────┘
```

**After responding (same URL, token still valid):**

```
┌─────────────────────────────────────────────────┐
│  OPENDEVIS                                       │
│                                                  │
│  ✅ Devis envoyé                                 │
│                                                  │
│  ┌──────────────────────────────────────────────┐│
│  │  Catégorie :  Plomberie 🔧                   ││
│  │  Votre prix : 3 800 € HT                    ││
│  │  Envoyé le :  10/03/2026 à 14:23            ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  Vous pouvez modifier votre prix jusqu'à la      │
│  date limite (17/03/2026 à 18:00).               │
│                                                  │
│  Prix total HT (€)                               │
│  ┌──────────────────────────┐                    │
│  │ 3800                     │                    │
│  └──────────────────────────┘                    │
│  [Mettre à jour]                                 │
└─────────────────────────────────────────────────┘
```

**Edge cases:**
- Invalid/unknown token → 404 page with "Ce lien n'est pas valide."
- Expired (past deadline) → show project summary but form replaced with: "La date limite est dépassée. Vous ne pouvez plus répondre."
- Already replaced → "Cette demande a été annulée."

---

## 8. Notifications (In-App Only — No Email for Now)

There are **NO outbound emails** in the current implementation. No SendGrid, no Action Mailer configuration needed.

### 8.1 How artisans learn about new requests

Artisans have accounts on the platform and check their **Artisan Dashboard** for new requests. They can also access a specific request via a **magic link** (token-based URL) which can be shared manually or added to email later.

### 8.2 How users (homeowners) are notified

In-app notifications only (via the `Notification` model + navbar badge). The user sees updates when they visit the platform.

### 8.3 Future: Email notifications

Email support (SendGrid or other) can be added later as a separate phase. The mailer structure is designed to be plugged in without changing the core flow:
- `ArtisanMailer#quote_request` — notify artisan of new request with magic link
- `UserNotificationMailer#artisan_responded` — notify user when artisan submits price
- `UserNotificationMailer#all_responded` — notify user when all responses are in
- `UserNotificationMailer#final_quote` — send PDF to user

When ready, configure Action Mailer with SMTP and implement these mailers. No model or controller changes needed.

---

## 9. AI Recommendation Logic

When the user opens the review page, compute a recommendation per category:

```ruby
# For each category in the bidding round:
#   1. Collect all BiddingRequests with status "responded"
#   2. Skip declined/expired/replaced
#   3. If no responses → show "Aucune réponse" for this category
#   4. Normalize:
#        price_score = 1 - (price - min_price) / (max_price - min_price)  # 1 = cheapest
#        rating_score = artisan.rating / 5.0                               # 1 = best rated
#        (if only one response, price_score = 1.0)
#   5. weighted_score = 0.6 * price_score + 0.4 * rating_score
#   6. Recommend artisan with highest weighted_score
```

This is simple, deterministic, and transparent. No LLM needed here — pure math. Display the reasoning: "Recommandé : meilleur rapport qualité-prix (prix compétitif + note de 4.5/5)".

---

## 10. Background Jobs

Use Solid Queue (Rails 8 default, already configured in the app).

| Job | Trigger | Action |
|-----|---------|--------|
| `BiddingDeadlineJob` | Scheduled at `bidding_round.deadline` | Mark unreplied requests as `expired`, notify user in-app |
| `GenerateFinalQuotePdfJob` | After user confirms selections | Generate PDF, attach to project |

---

## 11. Seed Data for Artisans

Add to `db/seeds.rb`. Create 10 artisans per work category, spread across several postcodes (75, 92, 93, 94 departments — Île-de-France). Each artisan covers 1-3 categories. Use realistic French names and company names. **All seed artisans use the same password for easy testing.**

```ruby
# Example structure (expand to 80+ artisans total):
# All artisans get password: "password123" (same as demo users)
artisans_data = [
  { name: "Jean Dupont",     email: "jean.dupont@email.com",     postcode: "75010", rating: 4.5, company_name: "Dupont Plomberie",    categories: ["plomberie"] },
  { name: "Marie Martin",    email: "marie.martin@email.com",    postcode: "75011", rating: 4.2, company_name: "Martin Électricité",  categories: ["electricite"] },
  { name: "Pierre Durand",   email: "pierre.durand@email.com",   postcode: "92100", rating: 3.8, company_name: "Durand & Fils",       categories: ["maconnerie", "isolation"] },
  # ... etc, ensure at least 10 per category per department
]

artisans_data.each do |data|
  artisan = Artisan.create!(
    name: data[:name],
    email: data[:email],
    password: "password123",
    postcode: data[:postcode],
    rating: data[:rating],
    company_name: data[:company_name]
  )
  data[:categories].each do |slug|
    cat = WorkCategory.find_by(slug: slug)
    ArtisanCategory.create!(artisan: artisan, work_category: cat) if cat
  end
end
```

Certifications to sprinkle: "RGE", "Qualibat", "QualiPV", "Handibat", "Qualit'EnR", "CAPEB membre".

---

## 12. Database Migrations

Create these migrations in order:

1. `DeviseCreateArtisans` — artisans table with Devise fields (`encrypted_password`, `reset_password_token`, etc.) + profile fields
2. `CreateArtisanCategories` — join table
3. `CreateBiddingRounds` — bidding_rounds table
4. `CreateBiddingRequests` — bidding_requests table with self-referential FK
5. `CreateFinalSelections` — final_selections table
6. `CreateNotifications` — notifications table

**Important:** Follow the convention from CLAUDE.md — do NOT modify existing tables. Only add new tables.

---

## 13. Implementation Phases

### Phase 1: Core Bidding Flow + Artisan Dashboard (build this first)
- Migrations + models + associations + validations (including Devise for artisans)
- Artisan seed data (with passwords for testing)
- Artisan Devise login/registration views (styled to match design system)
- Artisan Dashboard: home (request list), request detail + response form, profile page
- Artisan portal (magic link — token-based, no login)
- `BiddingRoundsController` with all user-facing actions
- Views: create round → select artisans → tracking → review → final quote
- Pundit policies for all new controllers
- AI recommendation logic (pure Ruby, no LLM needed)
- In-app notifications for users (Notification model + navbar badge)

### Phase 2: Real-time + Polish
- Turbo Streams for live tracking updates (when artisan submits via portal/dashboard)
- Deadline job (Solid Queue scheduled job to expire unanswered requests)
- PDF generation for final quote
- Artisan replacement flow (modal + re-send)
- Rating system (users rate artisans after project completion)

### Phase 3: Email Notifications (when ready)
- Configure Action Mailer with SendGrid (or other provider)
- Outbound emails: artisan quote request notification, user response notifications
- Final quote PDF sent by email to user

---

## 14. File Locations (where to put new code)

```
app/
├── controllers/
│   ├── bidding_rounds_controller.rb
│   ├── artisan_portal_controller.rb        # magic link (no auth)
│   ├── artisan_dashboard/
│   │   ├── base_controller.rb              # shared: authenticate_artisan!, layout
│   │   ├── home_controller.rb              # dashboard index
│   │   ├── requests_controller.rb          # show, submit_price, decline
│   │   └── profiles_controller.rb          # show, edit, update
│   └── notifications_controller.rb
├── models/
│   ├── artisan.rb                          # Devise model
│   ├── artisan_category.rb
│   ├── bidding_round.rb
│   ├── bidding_request.rb
│   ├── final_selection.rb
│   └── notification.rb
├── policies/
│   ├── bidding_round_policy.rb
│   ├── notification_policy.rb
│   └── artisan_portal_policy.rb            # skip_authorization for token-based
├── views/
│   ├── bidding_rounds/
│   │   ├── new.html.erb                    # Step 1: select categories + deadline
│   │   ├── select_artisans.html.erb        # Step 2: pick 3 artisans per category
│   │   ├── show.html.erb                   # Tracking page
│   │   ├── review_responses.html.erb       # AI recommendations + confirm
│   │   └── final_quote.html.erb            # Final consolidated quote
│   ├── artisan_portal/
│   │   └── show.html.erb                   # Magic link response form
│   ├── artisan_dashboard/
│   │   ├── home/
│   │   │   └── index.html.erb              # Dashboard with request list
│   │   ├── requests/
│   │   │   └── show.html.erb               # Request detail + response form
│   │   └── profiles/
│   │       ├── show.html.erb
│   │       └── edit.html.erb
│   ├── devise/artisans/                    # Artisan login/register views (customize)
│   │   ├── sessions/new.html.erb
│   │   ├── registrations/new.html.erb
│   │   └── registrations/edit.html.erb
│   ├── notifications/
│   │   └── index.html.erb
│   └── layouts/
│       └── artisan_dashboard.html.erb      # Separate layout with artisan navbar
├── jobs/
│   ├── bidding_deadline_job.rb
│   └── generate_final_quote_pdf_job.rb
└── javascript/
    └── controllers/
        ├── artisan_select_controller.js    # enforce 3-per-category selection
        ├── deadline_countdown_controller.js
        └── notification_badge_controller.js
```

---

## 15. Testing Notes

Write tests for:
- `Artisan.for_postcode(zip)` scope
- `BiddingRound` state machine transitions
- `BiddingRequest` token generation uniqueness
- AI recommendation scoring logic (unit test with known inputs)
- Artisan portal: valid token → show form, invalid/expired → 404
- Artisan dashboard: login required, only sees own requests
- Artisan Devise authentication (login, register, password reset)
- Controller integration tests for the full user flow
- Controller integration tests for the full artisan flow (dashboard + portal)

---

## 16. Design System Reminders

Match existing OpenDevis design from CLAUDE.md:
- Colors: Primary `#2C2A25`, Background `#FAFAF7`, Borders `#E8E4DC`, Muted `#9B9588`
- Cards: `border-radius: 10px`, subtle border, hover effect
- Buttons: `btn-dark-od` (primary), `btn-ghost-od` (secondary)
- Status badges: same rounded pill style as project statuses
- Use existing `cat-card` styling for category display
- All new forms use Simple Form with Bootstrap wrapper
