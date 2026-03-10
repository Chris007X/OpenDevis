# OpenDevis — Wireframe Specification

## Overview

This document describes the validated wireframes for OpenDevis. An interactive React prototype exists (built during the design phase) and can be referenced for exact layouts and interactions.

The production implementation uses **Rails views (ERB) + Bootstrap 5.3 + Hotwire (Turbo + Stimulus)**. No React in production.

---

## User Flow

```
Landing Page → Sign Up / Login
    ↓
Dashboard (projects#index)
    ↓
[+ Nouveau projet] → Wizard Step 1 (Property Info)
    → Step 2 (Renovation Type)
    → Step 3 (Work Categories)
    → Step 4 (Recap + Standing)
    → [Générer l'estimation]
    ↓
Results Page (projects#show)
    ↓
[Click room] → Room Detail (rooms#show)
```

---

## Screen Details

### 1. Dashboard

**Route:** `GET /projects` (`projects#index`)

**Layout:**
```
┌─────────────────────────────────────────────────┐
│ OPENDEVIS    Projets                    Marie D. │ ← navbar
├─────────────────────────────────────────────────┤
│                                                  │
│  Mes projets                    [+ Nouveau projet]│
│  3 projets                                       │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │ Appt     │  │ Maison   │  │ Studio   │      │
│  │ Rivoli   │  │ Vincennes│  │ Bastille │      │
│  │ 75001    │  │ 94300    │  │ 75011    │      │
│  │ En cours │  │ Terminé  │  │ Brouillon│      │
│  │ 42 350 € │  │ 87 200 € │  │ — €      │      │
│  │ 5p · 78m²│  │ 8p · 145m│  │ 2p · 32m²│      │
│  └──────────┘  └──────────┘  └──────────┘      │
└─────────────────────────────────────────────────┘
```

**Data per card:**
- `project.location_zip` or project name (if we add one later)
- Status badge from `project.status`
- `project.total_incVAT` formatted as currency
- `project.room_count` + `project.total_surface_sqm`
- `project.updated_at` formatted

**Empty state:** When `@projects.empty?`, show centered message with CTA.

---

### 2. Wizard Step 1 — Bien immobilier

**Route:** `GET /projects/new` or `GET /projects/wizard/step1`

```
┌─────────────────────────────────────────────────┐
│         ① ──── ② ──── ③ ──── ④                  │ ← stepper
│                                                  │
│  Décrivez votre bien                             │
│  Importez les infos ou remplissez manuellement.  │
│                                                  │
│  Importer automatiquement (facultatif)           │
│  ┌────────┐  ┌────────┐  ┌────────┐            │
│  │  🔗    │  │  📄    │  │  💬    │            │
│  │  URL   │  │  PDF   │  │  Chat  │            │
│  └────────┘  └────────┘  └────────┘            │
│                                                  │
│  [Expanded panel for selected mode]              │
│                                                  │
│  ┌─ Informations du bien ─── (tous facultatifs)─┐│
│  │  Type de bien    [____________]               ││
│  │  Surface (m²)    [____]  Pièces  [____]      ││
│  │  Code postal     [____]  DPE     [____]      ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  ← Retour                          [Suivant →]  │
└─────────────────────────────────────────────────┘
```

**Import modes (toggle panels):**
- URL: text input + "Analyser ✨" button
- PDF: drag & drop zone (file upload)
- Chat: inline mini-chat with input field

All modes are **future AI features** — for MVP, show the UI but the "Analyser" button can show a "coming soon" toast or simply not process.

---

### 3. Wizard Step 2 — Type de rénovation

**Route:** Wizard step (same page or separate route)

Single-select radio cards:
```
┌─────────────────────────────────────────────────┐
│  Type de rénovation                              │
│                                                  │
│  ○ 🎨 Rafraîchissement                          │
│  ○ 🔧 Rénovation légère                         │
│  ● 🚪 Rénovation par pièce     ← selected       │
│  ○ 🏗️ Rénovation complète                       │
│  ○ 🌿 Rénovation énergétique                    │
│  ○ 📐 Extension / Surélévation                  │
│  ○ 🏠 Construction neuve                        │
│                                                  │
│  ┌─ Quelles pièces rénover ? ──────────────────┐│ ← conditional
│  │  ☑ Salon (24 m²)                            ││
│  │  ☑ Cuisine (12 m²)                          ││
│  │  ☐ Chambre 1 (15 m²)                        ││
│  │  ☑ SDB (6 m²)                               ││
│  └──────────────────────────────────────────────┘│
└─────────────────────────────────────────────────┘
```

Room picker only appears when "Rénovation par pièce" is selected.

---

### 4. Wizard Step 3 — Travaux souhaités

**Route:** Wizard step

Adapts based on Step 2 selection.

**Default view (cosmetic/light/full):**
```
┌─────────────────────────────────────────────────┐
│  Travaux souhaités                               │
│                                                  │
│  [🔍 J'aimerais également ...              ]    │
│                                                  │
│  Structure & Réseaux (Technique)                 │
│  ┌────────┐  ┌────────┐  ┌────────┐            │
│  │  ⚡    │  │  🔧    │  │  🔨    │            │
│  │Électr. │  │Plomber.│  │Démol.  │            │
│  └────────┘  └────────┘  └────────┘            │
│                                                  │
│  Énergie & Confort (Thermique)                   │
│  ┌────────┐  ┌────────┐  ┌────────┐            │
│  │  🧱    │  │  🪟    │  │  🌡️    │            │
│  │Isolat. │  │Fenêtres│  │Chauff. │            │
│  └────────┘  └────────┘  └────────┘            │
│                                                  │
│  Pièces d'Eau                                    │
│  ┌────────┐  ┌────────┐  ┌────────┐            │
│  │  🍳    │  │  🚿    │  │  🚽    │            │
│  │Cuisine │  │  SDB   │  │  WC    │            │
│  └────────┘  └────────┘  └────────┘            │
│                                                  │
│  Menuiseries & Aménagement                       │
│  ┌────────┐  ┌────────┐  ┌────────┐            │
│  │  🖌️    │  │  ◻️    │  │  🛋️    │            │
│  │Peinture│  │ Sols   │  │Ameub.  │            │
│  └────────┘  └────────┘  └────────┘            │
│                                                  │
│  Autres / Besoins spécifiques                    │
│  [🔍 J'aimerais également ...              ]    │
└─────────────────────────────────────────────────┘
```

**"Par pièce" view:** Same grid but with room tabs at top.
**"Énergétique" view:** Only "Énergie & Confort" group.

---

### 5. Wizard Step 4 — Récapitulatif

```
┌─────────────────────────────────────────────────┐
│  Récapitulatif                                   │
│                                                  │
│  ┌─────────────────────────────────────────────┐│
│  │ Type: Appartement    Surface: 78 m²         ││
│  │ Code postal: 75001   Rénovation: Par pièce  ││
│  └─────────────────────────────────────────────┘│
│                                                  │
│  ┌─ Travaux sélectionnés ─────────────────────┐ │
│  │ Salon: [Peinture] [Sols]                    │ │
│  │ SDB: [Plomberie] [Carrelage] [Électricité]  │ │
│  └─────────────────────────────────────────────┘ │
│                                                  │
│  Niveau de standing                              │
│  [  Éco  ] [ Standard ] [ Premium ]              │
│                                                  │
│  ← Retour          [Générer l'estimation ✨]     │
└─────────────────────────────────────────────────┘
```

---

### 6. Results Page

**Route:** `GET /projects/:id` (`projects#show`)

```
┌─────────────────────────────────────────────────┐
│  Appt Rue de Rivoli          [Export PDF] [Share]│
│  75001 · 78 m² · 5 pièces                       │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌────────────────┐│
│  │ Total HT │  │Total TTC │  │ Standing       ││
│  │ 34 350 € │  │ 42 350 € │  │[Éco][Std][Prem]││
│  └──────────┘  └──────────┘  └────────────────┘│
│                                                  │
│  Par catégorie de travaux                        │
│  ┌────────┐  ┌────────┐  ┌────────┐            │
│  │🔧 Plomb│  │⚡ Élec │  │🖌️ Peint│            │
│  │12 posts│  │18 posts│  │9 postes│            │
│  │8 450 € │  │6 200 € │  │4 800 € │            │
│  └────────┘  └────────┘  └────────┘            │
│                                                  │
│  Par pièce  ← only if "par pièce" renovation     │
│  ┌─ Salon ──── 24 m² ────── 14 postes ─── → ──┐│
│  ┌─ Cuisine ── 12 m² ────── 18 postes ─── → ──┐│
│  ┌─ SDB ────── 6 m² ─────── 22 postes ─── → ──┐│
└─────────────────────────────────────────────────┘
```

**Standing toggle behavior:**
- Clicking Éco/Standard/Premium filters `work_items` by `standing_level`
- Updates Total HT, Total TTC, and all category subtotals
- Use Stimulus controller + Turbo Frame for instant update without full page reload

---

### 7. Room Detail

**Route:** `GET /rooms/:id` (`rooms#show`)

```
┌─────────────────────────────────────────────────┐
│  ← Appt Rue de Rivoli                           │
│                                                  │
│  [Salon] [Cuisine] [Chambre 1] [•SDB•] [Entrée] │ ← room tabs
│                                                  │
│  SDB  6 m²                    [+ Ajouter un poste]│
│                                                  │
│  ┌──────────────────────────────────────────────┐│
│  │ Désignation    │ Cat. │ Qté │P.U.HT│TVA│Tot ││
│  ├────────────────┼──────┼─────┼──────┼───┼────┤│
│  │ Dépose carrel. │Démol.│6 m² │ 18 € │10%│108 ││
│  │ Pose carrelage │ Sol  │6 m² │ 85 € │10%│510 ││
│  │ Receveur douche│Plomb.│1 u  │650 € │10%│650 ││
│  │ ...            │      │     │      │   │    ││
│  ├────────────────┼──────┼─────┼──────┼───┼────┤│
│  │ Total SDB      │      │     │      │   │3254││
│  └──────────────────────────────────────────────┘│
└─────────────────────────────────────────────────┘
```

Room tabs use Turbo Frames to swap content without page reload.
