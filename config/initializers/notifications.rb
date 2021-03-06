ActiveSupport::Notifications.subscribe("background_error") do |_name, _start, _finish, _id, payload|
  exception = payload[:exception]
  options = payload[:information] ? { data: { message: payload[:information] } } : {}
  ExceptionNotifier.notify_exception(exception, options)
  Rails.logger.error exception
  Rails.logger.error exception.backtrace.try(:join, "\n")
end
