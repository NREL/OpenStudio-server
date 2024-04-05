#!/bin/bash

# Obtain an initial authentication token with a proper TTL
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || echo "error")

# Function to refresh the token. Increases maintainability and reduces code duplication.
refresh_token() {
    echo 'Refreshing Authentication Token'
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || echo "error")
}

# Main loop to check for Spot Instance interruption notices
while sleep 5; do

    if [ "$TOKEN" == "error" ]; then
        # Attempt to refresh the token if the previous attempt failed.
        refresh_token
        # Skip this iteration if token retrieval fails again to avoid unnecessary operations.
        [ "$TOKEN" == "error" ] && continue
    fi

    HTTP_CODE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s -w "%{http_code}" -o /dev/null "http://169.254.169.254/latest/meta-data/spot/instance-action")

    case "$HTTP_CODE" in
        401)
            # Token expired or is otherwise invalid, refresh it.
            refresh_token
            ;;
        200)
            # code to handle instance interruption.
            echo "Instance interruption notice received. Requeuing datapoint."
            # Requeuing datapoint running on this worker.  There is only 1 and only 1 Resqueue worker
            ruby /opt/openstudio/server/bin/requeue.rb           
            ;;
        *)
            # In all other cases, no action is required.
            echo "No interruption detected. Continuing to monitor."
            ;;
    esac
done
