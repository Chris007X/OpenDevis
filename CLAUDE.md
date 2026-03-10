# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**OpenDevis** is a Rails 8 construction estimation/quote management system ("devis" = quote/estimate in French). It allows users to create projects, define rooms, and add work items with materials and pricing.

- Ruby 3.3.5, Rails 8.1.2, PostgreSQL
- Authentication: Devise | Authorization: Pundit
- Frontend: Bootstrap 5.3, Hotwire (Turbo + Stimulus), Simple Form

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
    └── has_many :rooms
        └── has_many :work_items
            ├── belongs_to :work_category
            └── belongs_to :material
                └── belongs_to :work_category
```

**WorkCategory** (Maçonnerie, Plomberie, Électricité, etc.) groups **Materials**. A **WorkItem** links a **Room** to a specific **Material** with quantity, unit price, and VAT rate. **Project** aggregates total costs (`total_exVAT`, `total_incVAT`).

### Key model details

- `Project#recompute_totals!` recalculates `total_exVAT` and `total_incVAT` from all work_items
- `WorkItem` has `standing_level` (integer: 1=Éco, 2=Standard, 3=Premium) — used to filter/display by price tier
- `WorkItem` auto-triggers `recompute_totals!` on Project after save/destroy
- `WorkCategory` has a `slug` field used for identification (e.g., "plomberie", "electricite", "peinture")

### Authentication & Authorization

`ApplicationController` requires login (`before_action :authenticate_user!`) and enforces Pundit authorization on every action. `skip_pundit?` excludes Devise, admin, and pages controllers. All new controllers need corresponding Pundit policies (stubs in `app/policies/` all default to `false` — fill them in).

### Database

Development: `open_devis_development` | Test: `open_devis_test`
Three additional Solid databases for cache, queue, and cable (Rails 8 defaults).

**Important:** Do NOT add new columns or migrations unless explicitly asked. The current schema is sufficient for the MVP.

### Seed Data

`db/seeds.rb` creates:
- 8 work categories: Maçonnerie, Plomberie, Électricité, Menuiserie, Peinture, Carrelage, Isolation, Chauffage
- 30 materials with real French brands (Grohe, Legrand, Velux, etc.)
- 2 demo users: `demo@opendevis.com` / `password123` and `bob@opendevis.com` / `password123`
- 4 projects with rooms and work items

## Code Style

RuboCop with `rubocop-rails-omakase` — max line length 120. Config in `.rubocop.yml`.

---

## UI/UX Specifications (from validated wireframes)

The following describes the target UI for OpenDevis. The interactive wireframe prototype is available in `docs/wireframe-spec.md`. All views use Bootstrap 5.3 + Hotwire (Turbo Frames/Streams + Stimulus controllers). No React.

### Design System

- **Colors:** Neutral warm palette. Primary dark: `#2C2A25`. Background: `#FAFAF7`. Borders: `#E8E4DC`. Muted text: `#9B9588`.
- **Typography:** System fonts with DM Sans feel. Clean, minimal.
- **Cards:** Rounded corners (8-10px), subtle border, light hover effect (border darkens, slight translateY).
- **Status badges:** Brouillon (warm gray), En cours (soft green), Terminé (soft blue).
- **Buttons:** Primary (dark fill), Secondary (light border), Ghost (transparent).

### Screen: Dashboard (`projects#index`)

The main screen after login. Shows all user projects as cards in a 3-column grid.

- Header: "Mes projets" + project count + prominent "**+ Nouveau projet**" button (top-right)
- **Project card** shows: project name/location_zip, status badge, total estimate amount (total_incVAT), room count, surface, last updated date
- Cards are clickable → navigate to project show (results page)
- **Empty state** (when no projects): centered illustration/icon + "Aucun projet pour le moment" + "Créez votre première estimation de travaux en quelques clics." + CTA button

### Screen: New Project Wizard (4-step flow)

The project creation is a **stepped wizard** with a visual stepper at the top showing 4 steps:
1. Bien immobilier
2. Type de rénovation
3. Travaux souhaités
4. Récapitulatif

**Implementation approach:** Use a dedicated controller (`Projects::WizardController`) or handle steps within `ProjectsController` using Turbo Frames. Each step saves progress to a `Project` in `draft` status. Back/forward navigation between steps.

#### Step 1: Bien immobilier (Property info)

Three **optional** import modes at the top (none selected by default):
- **🔗 URL d'annonce** — text input + "Analyser ✨" button (future: AI extracts property data from URL)
- **📄 PDF / Document** — drag & drop zone for file upload (future: AI extracts from PDF)
- **💬 Chat IA** — inline mini-chat where user describes the property in natural language (future: AI pre-fills fields)

Below the import modes, **manual fields are always visible and editable:**
- Type de bien (text)
- Surface totale m² (decimal)
- Nombre de pièces (integer)
- Code postal (string)
- DPE / Classe énergétique (A-G select)

All fields are **optional**. The "Suivant →" button is always enabled (user can skip and fill later).

When an import mode extracts data, a green success banner appears and fields are pre-filled but remain editable.

**Maps to:** `Project` model fields: `property_url`, `total_surface_sqm`, `room_count`, `location_zip`, `energy_rating`

#### Step 2: Type de rénovation

Single-select list of renovation types (radio-button style cards):
- 🎨 Rafraîchissement — "Peinture, petites retouches, décoration"
- 🔧 Rénovation légère — "Sols, peinture, petite plomberie/électricité"
- 🚪 Rénovation par pièce — "Rénovation ciblée de pièces spécifiques"
- 🏗️ Rénovation complète — "Refonte totale de l'appartement/maison"
- 🌿 Rénovation énergétique — "Isolation, fenêtres, chauffage, DPE"
- 📐 Extension / Surélévation — "Ajout de surface habitable"
- 🏠 Construction neuve — "Construction complète"

**Conditional sub-step:** If "Rénovation par pièce" is selected, a room picker appears inline below:
- List of rooms (from project data or generic defaults) with checkboxes
- User selects which rooms to renovate

**Note:** Renovation type is NOT stored as a DB column. It determines which work_categories are shown in Step 3 and can be stored in session or passed as params.

#### Step 3: Travaux souhaités (Work categories selection)

Content adapts based on Step 2 selection:

**For Rafraîchissement / Rénovation légère / Rénovation complète:** Full grid of work category cards organized in groups:
- **Structure & Réseaux (Technique):** Électricité ⚡, Plomberie 🔧, Démolition 🔨
- **Énergie & Confort (Thermique):** Isolation 🧱, Fenêtres 🪟, Système de chauffage 🌡️
- **Pièces d'Eau:** Cuisine 🍳, Salle de bain 🚿, WC 🚽
- **Menuiseries & Aménagement:** Peinture 🖌️, Sols ◻️, Ameublement & décoration 🛋️

Each category is a clickable toggle card (multi-select). A search bar "J'aimerais également..." at top and bottom.

**For Rénovation par pièce:** Same grid BUT displayed **per room** with tabs to switch between rooms. Each room has its own independent category selection. Tab shows room name + count of selected categories.

**For Rénovation énergétique:** Only shows the "Énergie & Confort (Thermique)" group: Isolation, Fenêtres, Système de chauffage.

**For Extension / Construction:** Simplified view with a free-text field to describe needs.

**Maps to:** The selected categories will determine which `WorkCategory` records to use when generating work items.

#### Step 4: Récapitulatif

Summary of all selections:
- Property info block (type, surface, zip, etc.)
- Renovation type label
- Selected work categories (as tags/chips), grouped by room if "par pièce"
- **Standing level selector:** 3 toggle buttons: Éco / Standard / Premium
  - Maps to `WorkItem#standing_level` (1, 2, 3)
  - Determines price tier for generated work items

CTA: "**Générer l'estimation ✨**" → creates the Project with Rooms and WorkItems, then redirects to results page.

### Screen: Results (`projects#show`)

The estimation results page. This is the most important screen.

**Header:** Project name + location + surface + room count. Action buttons: "Exporter PDF", "Partager".

**Summary bar (3 columns):**
- Total HT (dark card, large number)
- Total TTC (dark card, large number)
- **Standing toggle** (light card with 3 clickable buttons: Éco / Standard / Premium)
  - Clicking a standing level **instantly updates** all displayed prices (Turbo Frame or Stimulus)
  - Filters work_items by `standing_level` and recalculates totals
  - This is a KEY interaction — user can quickly compare price tiers

**Work categories section:** "Par catégorie de travaux" — 3-column grid of cards. Each card shows: category icon, category name, number of work items ("postes"), subtotal HT. Cards are clickable (future: expand to see items).

**Rooms section (conditional):** Only displayed if the project was created with "Rénovation par pièce" flow. Shows list of rooms with surface and item count. Each room is clickable → navigates to room detail.

**Note on standing toggle:** Use Stimulus controller to send AJAX request that filters work_items by standing_level and updates the Turbo Frame containing prices and category cards.

### Screen: Room Detail (`rooms#show`)

**Room tabs:** Horizontal pill buttons to switch between rooms (without page reload — Turbo Frames).

**Work items table:** Full-width table with columns:
- Désignation (label)
- Catégorie (work_category name)
- Qté (quantity + unit)
- P.U. HT (unit_price_exVAT)
- TVA (vat_rate %)
- Total HT (calculated)

Footer row: Total for the room.

"**+ Ajouter un poste**" button to add work items.

### Screen: Profile (`devise/registrations#edit` or custom)

Simple form: avatar placeholder (initials), full name, email, phone, location. Save button.

---

## Implementation Order (Recommended)

1. **Dashboard** (`projects#index`) — Rewrite view to match wireframe cards layout
2. **Results page** (`projects#show`) — Rewrite with summary bar, standing toggle (Stimulus), category cards, conditional room section
3. **Room detail** (`rooms#show`) — Room tabs + work items table
4. **Wizard Step 1** — Property info with import modes (start with manual fields only, AI import is future)
5. **Wizard Steps 2-4** — Renovation type selection, work categories, recap
6. **Standing toggle Stimulus controller** — AJAX standing filter on results page
7. **PDF export** — Future
8. **AI integration** — Future (URL analysis, chat, PDF extraction)

## Stimulus Controllers Needed

- `standing-toggle` — On results page: switches standing_level, updates prices via Turbo Frame
- `room-tabs` — On room detail + wizard step 3: switches between rooms without page reload
- `import-mode` — On wizard step 1: toggles between URL/PDF/Chat panels
- `category-select` — On wizard step 3: multi-select toggle for work category cards

## Turbo Frames Strategy

- `project_summary` — The summary bar + category cards on results page (refreshed when standing changes)
- `wizard_step` — Each wizard step content (allows back/forward without full page reload)
- `room_content` — Room detail content (switches when clicking room tabs)
