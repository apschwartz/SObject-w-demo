require 'forcedotcom'

# Set the default hostname for omniauth to send callbacks to.
# seems to be a bug in omniauth that it drops the httpS
# this still exists in 0.2.0
OmniAuth.config.full_host = 'https://localhost:3000'

module OmniAuth
  module Strategies
    #tell omniauth to load our strategy
    autoload :Forcedotcom, 'lib/forcedotcom'
  end
end


Rails.application.config.middleware.use OmniAuth::Builder do
  # Store your SF.com OAuth2 Consumer Key in the file lib/certs/oauth2_consumer_key
  # Store your SF.com OAuth2 Consumer Secret in the file lib/certs/oauth2_consumer_secret
  provider :forcedotcom, File.open("lib/certs/oauth2_consumer_key").read, File.open("lib/certs/oauth2_consumer_secret").read
end
