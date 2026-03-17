class CreateTestRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :test_runs do |t|
      t.datetime :ran_at,           null: false
      t.jsonb    :results,          default: {}
      t.integer  :pages_total,      default: 0
      t.integer  :pages_passed,     default: 0
      t.integer  :flows_total,      default: 0
      t.integer  :flows_passed,     default: 0
      t.integer  :ui_total,         default: 0
      t.integer  :ui_passed,        default: 0
      t.integer  :errors_count,     default: 0
      t.float    :duration_seconds, default: 0.0
      t.string   :trigger

      t.timestamps
    end

    add_index :test_runs, :ran_at
    add_index :test_runs, :results, using: :gin
  end
end
