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
    # Check if the file /opt/openstudio/server/bin/kill.worker exists
    if [ -f "/opt/openstudio/server/bin/kill.worker" ]; then
        echo "kill.worker file exists. Handling interruption."

        # Code to handle the interruption because kill.worker file exists
        echo "Instance interruption notice received. Requeuing datapoint."
        ruby /opt/openstudio/server/bin/requeue.rb >> /opt/openstudio/server/log/aws_imds.log 2>&1
        break
    fi

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
            ruby /opt/openstudio/server/bin/requeue.rb >> /opt/openstudio/server/log/aws_imds.log 2>&1
            break
            ;;
        *)
            # In all other cases, no action is required.
            echo "No interruption detected. Continuing to monitor."
            ;;
    esac
done
