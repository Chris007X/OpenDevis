class UserNotificationMailer < ApplicationMailer
  def artisan_responded(notification_id)
    @notification = Notification.find(notification_id)
    @user = @notification.user
    mail(to: @user.email, subject: @notification.title)
  end

  def final_quote_ready(project_id)
    @project = Project.find(project_id)
    @user = @project.user
    mail(to: @user.email, subject: "Votre devis finalisé — #{@project.location_zip}")
  end
end
