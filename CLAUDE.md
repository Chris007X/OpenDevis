# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**OpenDevis** is a Rails 8 construction estimation and bidding platform ("devis" = quote in French). Users create renovation projects via a wizard, receive AI-assisted property analysis, compare price tiers (Éco/Standard/Premium), then launch a bidding round to collect real artisan quotes by category.

- Ruby 3.3.5, Rails 8.1.2, PostgreSQL
- Authentication: Devise (users + artisans separately) | Authorization: Pundit
- Frontend: Bootstrap 5.3, Hotwire (Turbo + Stimulus), Simple Form
- AI/Analysis: PropertyUrlAnalyzer, PdfPropertyAnalyzer, PropertyChatAnalyzer (app/services/)

## Commands

```bash
bin/setup          # First-time setup: install gems, create & migrate DB
bin/dev            # Start development server

bin/rails test                              # Run all tests
bin/rails test test/models/user_test.rb    # Run a single test file

bin/rubocop        # Lint
bin/rubocop -A     # Auto-fix lint issues

bin/ci             # Full CI pipeline (rubocop, security checks, tests, seed test)
```

## Architecture

### Models & Relationships

```
User
└── has_many :projects
    ├── has_many :rooms
    │   └── has_many :work_items
    │       ├── belongs_to :work_category
    │       └── belongs_to :material
    ├── has_many :documents
    └── has_one :bidding_round
        └── has_many :bidding_requests
            ├── belongs_to :work_category
            └── belongs_to :artisan
        └── has_many :final_selections
            ├── belongs_to :work_category
            └── belongs_to :bidding_request

Artisan
├── has_many :artisan_categories → has_many :work_categories (through)
└── has_many :bidding_requests
```

**WorkCategory** (11 slugs: demolition_maconnerie, isolation, fenetres, toiture, electricite, plomberie, ventilation_chauffage, menuiseries_interieures, peintures, cuisine, salle_de_bain_wc) groups **Materials**. A **WorkItem** links a **Room** to a specific **Material** with quantity, unit price, VAT rate, and **standing_level** (1=Éco, 2=Standard, 3=Premium). **Project** aggregates total costs.

### Key Model Details

- `Project#recompute_totals!` recalculates `total_exVAT` and `total_incVAT` from all work_items
- `Project#photo_url` stores a local path (`/uploads/wizard_photos/…`) set during wizard step 1
- `WorkItem` auto-triggers `recompute_totals!` on Project after save/destroy
- `WorkCategory#slug` used for identification and wizard category filtering
- `BiddingRequest` broadcasts status changes via Turbo Streams; has unique token for artisan portal
- `BiddingRound` is unique per project (one bidding round at a time)

### Authentication & Authorization

- **Users** authenticate via Devise (email/password + Google OAuth via OmniAuth)
- **Artisans** authenticate via a separate Devise scope (`/artisans/sign_in`)
- `ApplicationController` requires `authenticate_user!` and enforces Pundit on every action
- `skip_pundit?` excludes Devise, pages, and artisan portal controllers
- All new controllers need a Pundit policy in `app/policies/`
- Artisan portal (`/artisan/respond/:token`) is **public** — no auth required

### Database

Development: `open_devis_development` | Test: `open_devis_test`
Three additional Solid databases for cache, queue, and cable (Rails 8 defaults).

**Important:** Do NOT add new columns or migrations unless explicitly asked.

### Seed Data

`db/seeds.rb` creates:
- 11 work categories with slugs (matching wizard slugs)
- 30+ materials with real French brands (Grohe, Legrand, Velux, etc.)
- Demo users: `demo@opendevis.com` / `password123` and `bob@opendevis.com` / `password123`
- Demo artisans per category
- 4 projects with rooms and work items

## Code Style

RuboCop with `rubocop-rails-omakase` — max line length 120. Config in `.rubocop.yml`.

---

## Implemented Features (current state)

### Wizard Flow (5 steps + choose screen)

**Choose screen** (`/projects/wizard/choose`): user picks project type (renovation / construction / extension). Clears all wizard session state.

**Step 1 — Bien immobilier** (`/projects/wizard/step1`):
- 3 AJAX import modes (URL, PDF, Chat IA) — each populates manual fields on success
- Manual fields: `property_type`, `total_surface_sqm`, `room_count`, `location_zip`, `energy_rating`, `description`
- Photo upload zone (drag/drop or click) → AJAX POST to `upload_photo` → saves to `/public/uploads/wizard_photos/` → stores URL in hidden `project[photo_url]`
- Photo extraction from PDF is **not supported** (PDF::Reader extracts text only, not embedded images)
- Project `name` field auto-fills on import with pattern: "Type Ville SURFACEm²" (e.g., "Appartement Paris 122m²")
- Routes: construction → step4, extension → step3, renovation → step2

**Step 2 — Type de rénovation** (`/projects/wizard/step2`):
- 7 renovation types as radio cards
- "Rénovation par pièce" shows inline room picker with +/- controls, room names, and surface inputs
- Session: `wizard_renovation_type`, `wizard_rooms`

**Step 3 — Travaux souhaités** (`/projects/wizard/step3`):
- Category grid adapts to renovation type (full grid / per-room tabs / energy-only / free text)
- "par_piece": room tabs with independent category selection per room
- Session: `wizard_categories`, `wizard_room_categories`, `wizard_custom_needs`

**Step 4 — Récapitulatif** (`/projects/wizard/step4`):
- Summary of all selections + standing level selector (Éco/Standard/Premium)
- "Générer l'estimation ✨" → creates rooms + work items (3 per category × standing level) → redirects to `projects#show`
- Standing multipliers: Éco × 0.75, Standard × 1.0, Premium × 1.40

### Project Dashboard (`projects#index`)
- 3-column card grid with: photo banner (if `photo_url` present, 130px cover), project name/zip, status badge, total TTC, room count, surface, last updated
- Delete button with confirmation modal (Stimulus `delete-confirm` controller)
- Empty state with CTA

### Results Page (`projects#show`)
- Summary bar: Total HT, Total TTC, standing toggle
- Work categories grid (3 columns): icon, name, item count, subtotal HT
- Rooms section (conditional, only for "par pièce" projects)
- Standing toggle via Stimulus → AJAX → Turbo Frame refresh

### Room Detail (`rooms#show`)
- Room tabs (Turbo Frames, no page reload)
- Work items table: label, category, quantity, unit price HT, VAT, total HT
- "+ Ajouter un poste" button

### Bidding Round Flow
1. `BiddingRound#new` — select standing level + categories to put out to tender
2. `select_artisans` — pick artisans per category (filtered by postcode + work_category)
3. `update_artisans` → `send_requests` — emails artisans via `ArtisanMailer` (job: `SendBiddingRequestEmailJob`)
4. `show` — track response status per category (Turbo Streams live updates)
5. `review_responses` — AI-scored recommendations per category
6. `confirm_selections` — finalize one artisan per category → creates `FinalSelection` records
7. `final_quote` — final quote summary (exportable to PDF via `FinalQuotePdfGenerator`)
8. `select_replacement` / `replace_artisan` — handle declined/missing artisans

### Artisan Portal (public, token-based)
- `GET /artisan/respond/:token` — artisan sees request details and can accept/decline/submit price
- `POST /artisan/respond/:token` — submits response, broadcasts via Turbo

### Artisan Dashboard (`/artisan_dashboard/`)
- Authenticated with separate Devise artisan scope
- Home: pending + past requests list
- Request detail: submit price or decline
- Profile: edit name, company, phone, postcode, work categories

### Other Features
- Documents: upload/delete files attached to a project
- Notifications: in-app notifications (unread badge, mark as read)
- User profile: full_name, phone, location
- Google OAuth login for users

---

## Stimulus Controllers (all implemented)

| Controller | Purpose |
|---|---|
| `photo-upload` | Drag/drop photo in wizard step 1, instant preview, AJAX upload |
| `renovation-type` | Show/hide room picker in step 2, manage room instances (+/-) |
| `import-mode` | Toggle URL/PDF/Chat panels in step 1 |
| `url-analyze` | AJAX property URL analysis |
| `pdf-upload` | Drag/drop PDF upload and analysis |
| `chat-property` | AI chat for property info |
| `property-type` | Show/hide `property_type_autre` field |
| `room-tabs` | Switch room tabs in room detail + wizard step 3 |
| `artisan-select` | Multi-select artisans by category in bidding flow |
| `bidding-step1` | Standing level + category selection for bidding round |
| `delete-confirm` | Confirmation modal for deletions |
| `notification-badge` | Update notification unread count |
| `city-autocomplete` | Autocomplete city/zip in step 1 |
| `card-tilt` | Hover tilt effect on cards |
| `wizard-form` | Form submission handling in wizard |

## Turbo Frames

- `project_summary` — Summary bar + category cards on results page (refreshed on standing change)
- `room_content` — Room detail content (switches on room tab click)
- BiddingRequest rows — broadcast status changes via Turbo Streams

## Services

- `PropertyUrlAnalyzer` — HTTP scrape of property listing URL, extracts fields + `photo_url`
- `PdfPropertyAnalyzer` — PDF::Reader text extraction, extracts fields (no image extraction)
- `PropertyChatAnalyzer` — AI chat interface, returns structured property fields

## Jobs

- `SendBiddingRequestEmailJob` — email artisans about new bidding requests
- `BiddingDeadlineJob` — handle deadline expiration
- `SendUserNotificationEmailJob` — email users about events (artisan responded, all responded, etc.)
- `GenerateFinalQuotePdfJob` — generate final quote PDF
- `ProcessInboundEmailJob` — handle artisan replies received by email

## Design System

- **Colors:** Primary dark `#2C2A25` · Background `#FAFAF7` · Borders `#E8E4DC` · Muted text `#9B9588`
- **Cards:** 8-10px radius, subtle border, hover → border darkens + translateY(-2px)
- **Status badges:** Brouillon (warm gray) · En cours (soft green) · Terminé (soft blue) · Refusé (red)
- **Buttons:** Primary (dark fill `#2C2A25`) · Secondary (light border) · Ghost (transparent)
- **Photo in project card:** 130px banner at top, `object-fit: cover`, rounded top corners only

## What NOT to Do

- Do not add columns or migrations without being explicitly asked
- Do not extract images from PDFs (technically not possible with PDF::Reader)
- Do not use `localStorage` (edge runtime incompatible in some contexts)
- Do not use React Server Actions
- Do not install new gems without explaining why
- Do not rewrite entire files to fix an isolated bug
