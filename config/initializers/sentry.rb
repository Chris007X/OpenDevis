Sentry.init do |config|
  config.dsn = ENV.fetch("SENTRY_DSN", nil)

  # Automatically capture breadcrumbs from Rails and HTTP calls
  config.breadcrumbs_logger = %i[active_support_logger http_logger]

  # Collect request headers and IP addresses — review for GDPR compliance before enabling in prod
  config.send_default_pii = false

  # Enable Sentry Logs (forwards Rails logger output)
  config.enable_logs = true
  config.enabled_patches = %i[logger]

  # Performance tracing: 0.1 = 10% of transactions in production to avoid overhead
  # Set to 1.0 locally for full visibility
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.1").to_f

  # Profiling: only samples transactions that are already traced
  config.profiles_sample_rate = 1.0
end
