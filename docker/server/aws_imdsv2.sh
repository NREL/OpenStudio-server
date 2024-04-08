#!/bin/bash
# Metadata service URL variable
#METADATA_URL="localhost:1338"
METADATA_URL="169.254.169.254"

# Obtain an initial authentication token with a proper TTL
TOKEN=$(curl -s -X PUT "http://${METADATA_URL}/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || echo "error")
last_token_status=""
last_message=""

# Function to log messages only if they've changed
log_if_changed() {
    local message=$1
    if [ "$message" != "$last_message" ]; then
        echo "$message"
        last_message="$message"
    fi
}

# Function to refresh the token. Increases maintainability and reduces code duplication.
refresh_token() {
    log_if_changed 'Refreshing Authentication Token'
    TOKEN=$(curl -s -X PUT "http://${METADATA_URL}/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || echo "error")
    if [ "$TOKEN" == "error" ]; then
        if [ "$last_token_status" != "error" ]; then
            log_if_changed 'Token Refresh Failed'
            last_token_status="error"
        fi
    else
        last_token_status="success"
    fi
}

# Check token status initially
if [ "$TOKEN" == "error" ]; then
    log_if_changed 'Token Refresh Failed'
    last_token_status="error"
else
    last_token_status="success"
fi

# Main loop to check for Spot Instance interruption notices
while sleep 5; do
    if [ -f "/opt/openstudio/server/bin/kill.worker" ]; then
        echo "kill.worker file exists. Handling interruption."
        echo "Instance interruption notice received. Requeuing datapoint."
        ruby /opt/openstudio/server/bin/requeue.rb >> /opt/openstudio/server/log/aws_imds.log 2>&1
        break
    fi

    HTTP_CODE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s -w "%{http_code}" -o /dev/null "http://${METADATA_URL}/latest/meta-data/spot/instance-action")
    
    case "$HTTP_CODE" in
        401)
            refresh_token
            ;;
        200)
            echo "Instance interruption notice received. Requeuing datapoint."
            ruby /opt/openstudio/server/bin/requeue.rb >> /opt/openstudio/server/log/aws_imds.log 2>&1
            break
            ;;
        *)
            log_if_changed "No interruption detected. Continuing to monitor."
            ;;
    esac
done
