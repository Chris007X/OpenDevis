class SendUserNotificationEmailJob < ApplicationJob
  queue_as :default

  def perform(notification_id)
    # Phase 3: send notification email
    Rails.logger.info "[SendUserNotificationEmailJob] notification #{notification_id} (Phase 3 not yet implemented)"
  end
end
