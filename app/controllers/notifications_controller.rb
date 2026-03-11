class NotificationsController < ApplicationController
  def index
    @notifications = policy_scope(Notification).recent
    authorize Notification
  end

  def mark_read
    @notification = current_user.notifications.find(params[:id])
    authorize @notification
    @notification.update!(read: true)
    redirect_back fallback_location: notifications_path
  end
end
