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
Each selected artisan receives an email with a summary of the work
    ↓
Artisan responds via:
  (a) Web portal (token-based magic link), OR
  (b) Email reply → AI agent parses and enters data on the platform
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
  → Sent to user via email
```

### Key constraints

- **One bidding round per project.** User picks one standing level, sends to artisans once. No re-runs.
- **Max 3 artisans per category.** User selects them from a displayed list of 10.
- **User can replace** an unresponsive artisan before the deadline (send to a different one from the remaining pool).
- Artisan response is **just a total price** for the category — no line-by-line breakdown.

---

## 2. New Models

### 2.1 `Artisan`

Represents a professional who can bid on work categories.

```ruby
# Fields:
#   name              :string, not null
#   email             :string, not null, unique
#   phone             :string
#   company_name      :string
#   postcode          :string, not null       # coverage area (match against project.location_zip)
#   rating            :decimal(3,2)           # average rating, 0.00–5.00
#   certifications    :text                   # comma-separated or JSON array of certification labels
#   portfolio_url     :string                 # link to external portfolio
#   active            :boolean, default: true
#
# Associations:
#   has_many :artisan_categories
#   has_many :work_categories, through: :artisan_categories
#   has_many :artisan_quotes
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
- `sent` — emails dispatched, waiting for responses
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
#   response_method    :string                # "web" | "email" | null
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
- `sent` — email dispatched to artisan
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
# Add to config/routes.rb inside `resources :projects do ... end`

resources :projects do
  # Existing:
  resources :rooms, only: [:index, :new, :create]
  resources :documents, only: [:index, :new, :create]

  # NEW — Artisan Bidding:
  resource :bidding_round, only: [:new, :create, :show] do
    post   :send_requests,       on: :member   # dispatch emails
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

# Artisan optional account (Devise with separate model or STI — decide later):
# For now, artisans don't log in. Token-based only. Optional account is Phase 2.

# Inbound email webhook (for AI parsing of artisan email replies):
post "webhooks/inbound_email", to: "webhooks/inbound_email#create"

# Notification badge:
resources :notifications, only: [:index] do
  post :mark_read, on: :member
end
```

---

## 5. User Flow (extended)

Extends the flow from `docs/wireframe-spec.md`:

```
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
                              [Envoyer les demandes] → emails dispatched
                                   ↓
                              Tracking Page (monitor responses)
                                   ↓
                              Review & Confirm (AI recommendations)
                                   ↓
                              Final Consolidated Quote (view + PDF)
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
   - Enqueue `SendBiddingRequestEmailJob` (see §8)
   - Set status → `sent`, set `sent_at`
2. Set `BiddingRound.status` → `sent`
3. Redirect to tracking page: `project_bidding_round_path(@project)`

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
- Selecting a replacement: marks old request as `replaced`, creates a new `BiddingRequest`, sends email to new artisan

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
│  [Télécharger le PDF]    [Envoyer par email]    │
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
- "Envoyer par email" → `POST` that sends the PDF + summary to `current_user.email`

---

## 7. Screen Details — Artisan Portal

### 7.1 Token-based access (no login required)

**Route:** `GET /artisan/respond/:token`

The artisan clicks the link from their email. The token identifies the `BiddingRequest`.

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
│  │                                              ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  [Envoyer mon devis]       [Décliner]           │
│   ↑ btn-dark-od             ↑ btn-ghost-od       │
│                                                  │
│  📅 Date limite : 17/03/2026 à 18:00            │
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

### 7.2 Optional artisan account (Phase 4 — not in first implementation)

Later: artisans can create an account to see their history of requests, track responses, manage their profile. Defer this — for now, token-based only.

---

## 8. Email Specifications

### 7.1 Email service recommendation: **Postmark**

Recommended for:
- Excellent deliverability (important — artisan emails must not land in spam)
- Built-in inbound email parsing (webhook-based)
- Simple API, good Rails integration (`postmark-rails` gem)
- Reasonable pricing for transactional email

Alternative: **SendGrid** if you prefer a more established platform with broader features.

### 7.2 Outbound: Quote request to artisan

**From:** `devis@opendevis.com` (or similar branded address)
**To:** artisan's email
**Subject:** `"Demande de devis — [Category Name] — [Postcode]"`

**Body (HTML email):**
```
Bonjour [Artisan Name],

Vous avez reçu une demande de devis pour des travaux de [category name].

📋 Résumé du projet :
• Catégorie : [Category Name]
• Surface totale : [XX] m²
• Nombre de pièces : [X]
• Niveau de standing : [Éco / Standard / Premium]
• Localisation : [Postcode]

💰 Estimation initiale (référence) : [subtotal HT for this category] € HT

📅 Date limite de réponse : [deadline formatted as "DD/MM/YYYY à HH:MM"]

👉 Répondre en ligne : [MAGIC LINK BUTTON → /artisan/respond/:token]

Vous pouvez également répondre directement à cet email en indiquant votre prix total HT.

Cordialement,
L'équipe OpenDevis
```

**Reply-to address:** Use a unique inbound address per request for AI parsing:
`devis+[token]@inbound.opendevis.com`

This allows the inbound email parser to match the reply to the correct `BiddingRequest` via the token in the address.

### 7.3 Inbound: AI parsing of artisan email replies

**Webhook endpoint:** `POST /webhooks/inbound_email`

**Processing logic (in a background job):**
1. Extract the token from the `To` address (parse `devis+[token]@inbound.opendevis.com`)
2. Find the `BiddingRequest` by token
3. Validate: request is still `sent` status, deadline not passed
4. **AI extraction:** Send the email body text to an LLM (Claude API via Anthropic SDK) with prompt:
   ```
   Extract the total price (HT, in euros) from this artisan's email reply.
   If the artisan is declining the request, return {"declined": true}.
   If you can find a price, return {"price": <number>}.
   If you cannot determine a price or decline, return {"unclear": true, "reason": "..."}.
   
   Email body:
   ---
   [email_body_text]
   ---
   
   Respond ONLY with valid JSON, no other text.
   ```
5. If price extracted → update `BiddingRequest`: `status: "responded"`, `price_total: <price>`, `response_method: "email"`, `responded_at: Time.current`
6. If declined → update status to `"declined"`
7. If unclear → flag for manual review (create a Notification for the user: "Réponse de [artisan] nécessite une vérification")
8. After each response: check if all active requests for the bidding round are resolved → if yes, trigger "all responded" notification + email

### 7.4 User notification emails

**When an artisan responds:**
- Subject: `"[Artisan Name] a répondu — [Category Name]"`
- Body: brief summary + link to tracking page

**When all artisans have responded:**
- Subject: `"Toutes les réponses reçues — [Project Name]"`
- Body: summary of all prices + link to review page

**Final consolidated quote:**
- Subject: `"Votre devis finalisé — [Project Name]"`
- Body: total price + breakdown + PDF attached

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
| `SendBiddingRequestEmailJob` | After `send_requests` action | Send one email per BiddingRequest |
| `ProcessInboundEmailJob` | Webhook receives email | AI parsing + update BiddingRequest |
| `BiddingDeadlineJob` | Scheduled at `bidding_round.deadline` | Mark unreplied requests as `expired`, notify user |
| `SendUserNotificationEmailJob` | After artisan response / all responded / final quote | Send notification email to user |
| `GenerateFinalQuotePdfJob` | After user confirms selections | Generate PDF, attach to project |

---

## 11. Seed Data for Artisans

Add to `db/seeds.rb`. Create 10 artisans per work category, spread across several postcodes (75, 92, 93, 94 departments — Île-de-France). Each artisan covers 1-3 categories. Use realistic French names and company names.

```ruby
# Example structure (expand to 80+ artisans total):
artisans_data = [
  { name: "Jean Dupont",     email: "jean.dupont@email.com",     postcode: "75010", rating: 4.5, company_name: "Dupont Plomberie",    categories: ["plomberie"] },
  { name: "Marie Martin",    email: "marie.martin@email.com",    postcode: "75011", rating: 4.2, company_name: "Martin Électricité",  categories: ["electricite"] },
  { name: "Pierre Durand",   email: "pierre.durand@email.com",   postcode: "92100", rating: 3.8, company_name: "Durand & Fils",       categories: ["maconnerie", "isolation"] },
  # ... etc, ensure at least 10 per category per department
]
```

Certifications to sprinkle: "RGE", "Qualibat", "QualiPV", "Handibat", "Qualit'EnR", "CAPEB membre".

---

## 12. Database Migrations

Create these migrations in order:

1. `CreateArtisans` — artisans table
2. `CreateArtisanCategories` — join table
3. `CreateBiddingRounds` — bidding_rounds table
4. `CreateBiddingRequests` — bidding_requests table with self-referential FK
5. `CreateFinalSelections` — final_selections table
6. `CreateNotifications` — notifications table

**Important:** Follow the convention from CLAUDE.md — do NOT modify existing tables. Only add new tables.

---

## 13. Implementation Phases

### Phase 1: Core Bidding Flow (build this first)
- Migrations + models + associations + validations
- Artisan seed data
- `BiddingRoundsController` with all user-facing actions
- Views: create round → select artisans → tracking → review → final quote
- Pundit policies for all new controllers
- Artisan portal (token-based show + submit)
- Basic email sending (outbound only — use Action Mailer, configure Postmark later)
- AI recommendation logic (pure Ruby, no LLM needed)
- In-app notifications (Notification model + navbar badge)

### Phase 2: Email Intelligence
- Inbound email webhook + AI parsing (Claude API)
- `ProcessInboundEmailJob`
- Reply-to address routing

### Phase 3: Real-time + Polish
- Turbo Streams for live tracking updates
- Deadline job (Solid Queue scheduled job)
- User notification emails
- PDF generation for final quote
- Artisan replacement flow (modal + re-send)

### Phase 4: Artisan Accounts
- Optional artisan registration/login (Devise with `:artisan` scope or separate model)
- Artisan dashboard: history of requests, profile management
- Rating system (users rate artisans after project completion)

---

## 14. File Locations (where to put new code)

```
app/
├── controllers/
│   ├── bidding_rounds_controller.rb
│   ├── artisan_portal_controller.rb
│   ├── webhooks/
│   │   └── inbound_email_controller.rb
│   └── notifications_controller.rb
├── models/
│   ├── artisan.rb
│   ├── artisan_category.rb
│   ├── bidding_round.rb
│   ├── bidding_request.rb
│   ├── final_selection.rb
│   └── notification.rb
├── policies/
│   ├── bidding_round_policy.rb
│   ├── notification_policy.rb
│   └── artisan_portal_policy.rb        # skip_authorization for token-based
├── views/
│   ├── bidding_rounds/
│   │   ├── new.html.erb                 # Step 1: select categories + deadline
│   │   ├── select_artisans.html.erb     # Step 2: pick 3 artisans per category
│   │   ├── show.html.erb                # Tracking page
│   │   ├── review_responses.html.erb    # AI recommendations + confirm
│   │   └── final_quote.html.erb         # Final consolidated quote
│   ├── artisan_portal/
│   │   └── show.html.erb                # Artisan response form
│   └── notifications/
│       └── index.html.erb
├── mailers/
│   ├── artisan_mailer.rb                # quote_request, reminder
│   └── user_notification_mailer.rb      # artisan_responded, all_responded, final_quote
├── jobs/
│   ├── send_bidding_request_email_job.rb
│   ├── process_inbound_email_job.rb
│   ├── bidding_deadline_job.rb
│   ├── send_user_notification_email_job.rb
│   └── generate_final_quote_pdf_job.rb
└── javascript/
    └── controllers/
        ├── artisan_select_controller.js  # enforce 3-per-category selection
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
- Controller integration tests for the full flow
- Mailer previews for all emails

---

## 16. Design System Reminders

Match existing OpenDevis design from CLAUDE.md:
- Colors: Primary `#2C2A25`, Background `#FAFAF7`, Borders `#E8E4DC`, Muted `#9B9588`
- Cards: `border-radius: 10px`, subtle border, hover effect
- Buttons: `btn-dark-od` (primary), `btn-ghost-od` (secondary)
- Status badges: same rounded pill style as project statuses
- Use existing `cat-card` styling for category display
- All new forms use Simple Form with Bootstrap wrapper
