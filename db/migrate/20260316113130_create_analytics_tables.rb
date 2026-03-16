class CreateAnalyticsTables < ActiveRecord::Migration[8.1]
  def change
    create_table :analytics_events do |t|
      t.string :event_type, null: false
      t.string :user_id
      t.string :session_id
      t.string :page_path
      t.string :referrer
      t.string :user_agent
      t.string :ip_address
      t.string :country_code
      t.jsonb :properties, default: {}
      t.integer :duration_ms
      t.integer :page_load_time_ms
      t.boolean :completed, default: false

      t.timestamps
    end

    add_index :analytics_events, :event_type
    add_index :analytics_events, :session_id
    add_index :analytics_events, [ :event_type, :created_at ]
    add_index :analytics_events, [ :user_id, :created_at ]
    add_index :analytics_events, :created_at
    add_index :analytics_events, :properties, using: :gin

    create_table :analytics_sessions do |t|
      t.string :session_id, null: false
      t.string :user_id
      t.string :country_code
      t.string :device_type
      t.string :browser
      t.integer :page_views, default: 0
      t.integer :events_count, default: 0
      t.integer :duration_seconds, default: 0
      t.string :first_page
      t.string :last_page
      t.datetime :started_at
      t.datetime :ended_at
      t.boolean :converted, default: false
      t.string :drop_off_page

      t.timestamps
    end

    add_index :analytics_sessions, :session_id, unique: true
    add_index :analytics_sessions, :user_id
    add_index :analytics_sessions, :started_at

    create_table :analytics_funnels do |t|
      t.string :funnel_name, null: false
      t.string :user_id
      t.string :session_id
      t.integer :step_number
      t.string :step_name
      t.boolean :completed, default: false
      t.integer :time_to_complete_ms

      t.timestamps
    end

    add_index :analytics_funnels, :funnel_name
    add_index :analytics_funnels, :session_id
    add_index :analytics_funnels, [ :funnel_name, :step_number, :created_at ]

    create_table :analytics_daily_stats do |t|
      t.date :date, null: false
      t.integer :unique_users, default: 0
      t.integer :total_events, default: 0
      t.integer :total_sessions, default: 0
      t.float :avg_session_duration, default: 0.0
      t.float :conversion_rate, default: 0.0
      t.integer :errors_count, default: 0

      t.timestamps
    end

    add_index :analytics_daily_stats, :date, unique: true
  end
end
