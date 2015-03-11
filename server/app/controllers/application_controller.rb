class ApplicationController < ActionController::Base
  protect_from_forgery

  # set 'online' value. only do this once (if no value exists)
  status = Status.first
  if status.nil?
    # set now
    s = Status.new
    s.awake = Time.now
    s.save
  end
end
