#!/bin/bash


# Main loop to check for Spot Instance interruption notices
while sleep 5; do

    # Check if the file /opt/openstudio/server/bin/kill.worker exists
    if [ -f "/opt/openstudio/server/bin/kill.worker" ]; then
        echo "kill.worker file exists. Handling interruption."

        # Code to handle the interruption because kill.worker file exists
        echo "Instance interruption notice received. Requeuing datapoint."
        ruby /opt/openstudio/server/bin/requeue.rb >> /opt/openstudio/server/log/aws_imds.log 2>&1
        break
    else
        echo "No interruption detected. Continuing to monitor."
    fi
done
