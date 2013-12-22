# Install this the SDK with "gem install dropbox-sdk"
require 'dropbox_sdk'

# Get your app key and secret from the Dropbox developer website
APP_KEY = 'e6xvmni5q7lxcnc'
APP_SECRET = 'dqpui54ap9cd84p'

flow = DropboxOAuth2FlowNoRedirect.new(APP_KEY, APP_SECRET)
authorize_url = flow.start()

# Have the user sign in and authorize this app
puts '1. Go to: ' + authorize_url
puts '2. Click "Allow" (you might have to log in first)'
puts '3. Copy the authorization code'
print 'Enter the authorization code here: '
code = gets.strip

# This will fail if the user gave us an invalid authorization code
access_token, user_id = flow.finish(code)

client = DropboxClient.new(access_token)

p access_token

client.put_file('/pdf.pdf', 'pdf.pdf')