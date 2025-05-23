# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Be sure to restart your server when you modify this file.
# Configure sensitive parameters which will be filtered from the log file.
#Rails.application.config.filter_parameters += [:password, /\Aanalysis(?!\_)/]
#Rails.application.config.filter_parameters += [:password, /\Aanalysis(?!\_)/, :file]

# Be sure to restart your server when you modify this file.

# Configure parameters to be filtered from the log file. Use this to limit dissemination of
# sensitive information. See the ActiveSupport::ParameterFilter documentation for supported
# notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn,
  :password, /\Aanalysis(?!\_)/, :file
]
