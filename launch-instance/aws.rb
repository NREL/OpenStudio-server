require 'aws'
AWS.config(
    :access_key_id => 'xxxxxxxxxxxxxxxxxxxx',
    :secret_access_key => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    :ssl_verify_peer => false
)

cw = AWS::CloudWatch.new
resp = cw.client.list_metrics
puts resp
