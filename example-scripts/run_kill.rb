require './ServerApi.rb'

HOSTNAME = "http://localhost:8080"
#HOSTNAME = "http://ec2-107-22-88-62.compute-1.amazonaws.com"
WITHOUT_DELAY=false

options = {hostname: HOSTNAME}
api = ServerApi.new(options)

api.kill_all_analyses