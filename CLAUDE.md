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

### Authentication & Authorization

`ApplicationController` requires login (`before_action :authenticate_user!`) and enforces Pundit authorization on every action. `skip_pundit?` excludes Devise, admin, and pages controllers. All new controllers need corresponding Pundit policies (stubs in `app/policies/` all default to `false` — fill them in).

### Database

Development: `open_devis_development` | Test: `open_devis_test`
Three additional Solid databases for cache, queue, and cable (Rails 8 defaults).

### Seed Data

`db/seeds.rb` creates 8 work categories, 10 materials, 1 demo user (`demo@opendevis.com` / `password123`), 1 demo project with 3 rooms and 4 work items.

## Code Style

RuboCop with `rubocop-rails-omakase` — max line length 120. Config in `.rubocop.yml`.
