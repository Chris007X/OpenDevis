class RunTestSuiteJob < ApplicationJob
  queue_as :default

  def perform
    e2e_dir = Rails.root.join("e2e").to_s
    app_base = ENV.fetch("APP_BASE_URL", "http://localhost:3000")

    env = {
      "RESULTS_URL"       => "#{app_base}/test_runs",
      "SKIP_AI"           => "true",
      "TRIGGER"           => "manual",
      "LD_LIBRARY_PATH"   => "/tmp/chromium-libs/usr/lib/x86_64-linux-gnu"
    }
    env["OPENDEVIS_TEST_TOKEN"] = ENV["OPENDEVIS_TEST_TOKEN"] if ENV["OPENDEVIS_TEST_TOKEN"].present?
    env["BASE_URL"]             = ENV["E2E_BASE_URL"]         if ENV["E2E_BASE_URL"].present?

    system(env, "node", "run_tests.mjs", chdir: e2e_dir)
  end
end
