# OpenDevis Analytics System

## Project Overview

Building a **free/open-source analytics stack** for OpenDevis (B2C property bidding platform). Goal: track user acquisition, feature usage, funnel analytics, drop-off points, and performance issues — all self-hosted.

**Tech Stack:**
- Frontend: Rails 8.1 + Hotwired/Turbo + Stimulus
- Backend: Rails with PostgreSQL
- Analytics DB: PostgreSQL (analytics_* tables)
- Background Jobs: Solid Queue
- Tools: Glitchtip (errors), OpenReplay (sessions), OpenTelemetry (performance)
- Dashboard: Custom Rails admin panel at `/analytics`

## What We're Tracking

1. **Events** — Page views, clicks, form submissions, conversions
2. **Sessions** — User journeys, time on site, drop-off pages
3. **Funnels** — Multi-step conversions (quote → bid → contract)
4. **Performance** — Page load times, slow endpoints, error rates
5. **Errors** — Application exceptions (via Glitchtip SDK)
6. **Recordings** — User sessions (via OpenReplay SDK)

## Database Schema

### `analytics_events` table
Core tracking table for all user actions.

```ruby
create_table :analytics_events do |t|
  t.string :event_type, null: false, index: true     # 'page_view', 'click', 'form_submit', etc
  t.string :user_id                                   # nil if anonymous
  t.string :session_id, index: true                   # correlate events
  t.string :page_path                                 # /artisans, /quotes, etc
  t.string :referrer                                  # where user came from
  
  # User properties
  t.string :user_agent
  t.string :ip_address
  t.string :country_code
  
  # Event data (flexible JSON)
  t.jsonb :properties, default: {}                    # {button_clicked: 'submit', form_id: 123}
  
  # Performance
  t.integer :duration_ms                              # time until next event
  t.integer :page_load_time_ms                        # how long page took to load
  
  # Conversion tracking
  t.boolean :completed, default: false                # did user complete flow?
  
  t.timestamps
  t.index [:event_type, :created_at]
  t.index [:user_id, :created_at]
  t.index [:created_at]
end
```

### `analytics_sessions` table
Denormalized session data for fast queries.

```ruby
create_table :analytics_sessions do |t|
  t.string :session_id, null: false, index: true
  t.string :user_id
  t.string :country_code
  t.string :device_type                               # mobile, tablet, desktop
  t.string :browser
  
  # Metrics
  t.integer :page_views, default: 0
  t.integer :events_count, default: 0
  t.integer :duration_seconds, default: 0
  t.string :last_page
  t.string :first_page
  
  # Timing
  t.datetime :started_at
  t.datetime :ended_at
  
  # Conversion
  t.boolean :converted, default: false
  t.string :drop_off_page                             # where did they abandon?
  
  t.timestamps
  t.index [:started_at]
  t.index [:user_id]
end
```

### `analytics_funnels` table
Track multi-step conversions.

```ruby
create_table :analytics_funnels do |t|
  t.string :funnel_name, null: false, index: true     # 'quote_to_contract'
  t.string :user_id
  t.string :session_id, index: true
  t.integer :step_number                              # 1, 2, 3...
  t.string :step_name                                 # 'viewed_quote', 'submitted_bid', 'signed_contract'
  t.boolean :completed
  t.integer :time_to_complete_ms                      # time to reach this step
  
  t.timestamps
  t.index [:funnel_name, :step_number, :created_at]
end
```

### `analytics_daily_stats` table
Pre-aggregated daily metrics for dashboard performance.

```ruby
create_table :analytics_daily_stats do |t|
  t.date :date, null: false, index: true
  t.integer :unique_users, default: 0
  t.integer :total_events, default: 0
  t.integer :total_sessions, default: 0
  t.float :avg_session_duration, default: 0
  t.float :conversion_rate, default: 0
  t.integer :errors_count, default: 0
  
  t.timestamps
end
```

## Models & Methods

### AnalyticsEvent
```ruby
class AnalyticsEvent < ApplicationRecord
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_page, ->(path) { where(page_path: path) }
  scope :by_type, ->(type) { where(event_type: type) }
  scope :recent, ->(days = 7) { where('created_at > ?', days.days.ago) }
  
  def self.event_summary(days = 7)
    # Returns {event_type => count} sorted by count
  end
  
  def self.drop_off_analysis(days = 7)
    # Returns pages where users abandon
  end
end
```

### AnalyticsSession
```ruby
class AnalyticsSession < ApplicationRecord
  has_many :events, foreign_key: :session_id, primary_key: :session_id
  
  scope :recent, ->(days = 7) { where('started_at > ?', days.days.ago) }
  scope :converted, -> { where(converted: true) }
  scope :abandoned, -> { where(converted: false) }
  
  def self.conversion_rate(days = 7)
    # Returns percentage of sessions that converted
  end
  
  def self.avg_duration(days = 7)
    # Returns average session duration in seconds
  end
end
```

### AnalyticsTracker (Service)
```ruby
# Usage: AnalyticsTracker.track(event_type: 'page_view', user_id: @user.id, page_path: '/quotes')
# Background job enqueues the actual DB insert to avoid blocking requests

class AnalyticsTracker
  def self.track(event_type:, user_id: nil, session_id: nil, **properties)
    # Enqueue TrackingJob for async processing
    TrackingJob.perform_later(event_type, user_id, session_id, properties)
  end
end
```

## Key Commands

```bash
# Create migration
bin/rails generate migration CreateAnalyticsTables

# Run migrations
bin/rails db:migrate

# Test analytics
bin/rails test test/models/analytics_*

# Rails console (test queries)
bin/rails console
> AnalyticsEvent.event_summary(7)
> AnalyticsSession.conversion_rate(7)
```

## Architecture Flow

```
Browser (JavaScript)
    ↓ (navigator.sendBeacon)
Rails Controller
    ↓
AnalyticsTracker.track() [enqueues job]
    ↓
Solid Queue (background job)
    ↓
AnalyticsEvent.create!
    ↓
PostgreSQL (analytics_events table)
    ↓
Dashboard queries (scopes, aggregates)
    ↓
/analytics admin view (charts, metrics)
```

## Frontend Tracking (JavaScript)

Where to add tracking calls:

1. **Page views** — Add to layout view after page load
2. **Clicks** — Add `data-track-event` to buttons/links
3. **Form submissions** — Track on form submit
4. **Time on page** — Auto-track duration before page unload
5. **Errors** — Catch JS errors and send to Glitchtip

Example:
```javascript
// Track page view
Analytics.track('page_view', {
  page_path: '/quotes',
  referrer: document.referrer
});

// Track click
Analytics.track('click', {
  button: 'contact_artisan',
  quote_id: 123
});
```

## Common Queries for Dashboard

```ruby
# Traffic
AnalyticsEvent.recent(7).count  # Total events last 7 days
AnalyticsSession.recent(7).count  # Total sessions
AnalyticsEvent.recent(7).distinct.count(:user_id)  # Unique users

# Conversion
AnalyticsSession.conversion_rate(7)  # % converted
AnalyticsSession.avg_duration(7)  # Avg session time

# Drop-off analysis
AnalyticsEvent.recent(7).where(completed: false).group(:page_path).count

# Feature usage
AnalyticsEvent.recent(7).where(event_type: 'click').group(:properties).count

# Performance
AnalyticsEvent.recent(7).where.not(page_load_time_ms: nil).average(:page_load_time_ms)
```

## Constraints & Gotchas

- **Session ID** — Set via middleware, correlates all events to user session
- **User privacy** — Don't store email/name; use user_id + anonymization
- **Background jobs** — Use Solid Queue for async tracking (don't block requests)
- **Indexes** — Critical on created_at, user_id, event_type, session_id
- **Retention** — Keep raw events 90 days, archive to daily_stats after
- **Scale** — Prepare for 100+ events/second; use proper indexes + partitioning if needed

## Deployment

- **Migration**: `bin/rails db:migrate RAILS_ENV=production`
- **Kamal**: Includes migration step before starting new containers
- **Monitoring**: Glitchtip + OpenTelemetry dashboards
- **Backups**: PostgreSQL backups include analytics tables

## Integration with External Tools

### Glitchtip (Error Tracking)
Add to Gemfile: `gem 'sentry-rails'` or self-host Glitchtip  
Configuration: `.env` with GLITCHTIP_DSN

### OpenReplay (Session Recording)
Add JavaScript SDK to `app/views/layouts/application.html.erb`  
Configuration: `.env` with OPENREPLAY_PROJECT_KEY

### OpenTelemetry (Performance)
Add gems: `opentelemetry-api`, `opentelemetry-sdk`, `opentelemetry-exporter-trace`  
Configuration: Jaeger or similar backend

## Next Steps (Priority)

1. ✅ Create analytics_* tables (migration)
2. ✅ Create models with scopes
3. ✅ Build AnalyticsTracker service + TrackingJob
4. ✅ Add frontend JavaScript tracking module
5. ✅ Build admin dashboard views with charts
6. ✅ Create funnel analyzer (quote → bid → contract)
7. ⭐ Integrate Glitchtip SDK for error tracking
8. ⭐ Integrate OpenReplay SDK for session recordings
9. ⭐ Deploy infrastructure + monitoring

## Testing

```bash
# Run analytics tests
bin/rails test test/models/analytics_event_test.rb
bin/rails test test/jobs/tracking_job_test.rb

# Test tracking in console
bin/rails console
> AnalyticsTracker.track(event_type: 'test', user_id: 1)
> AnalyticsEvent.last
```

## Code Style

- Rails conventions (RESTful, ActiveRecord)
- Prefer service objects for business logic
- Use scopes for database queries
- Add indexes on columns used in WHERE/JOIN/GROUP BY
- Document complex logic with comments

---

**Last Updated:** March 2025  
**Status:** In Development  
**Owner:** OpenDevis Analytics Team
