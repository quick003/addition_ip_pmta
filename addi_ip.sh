#!/bin/bash

echo "please cancel this run and check your network name is eth0 or ens33"

echo "If you know network name continue running the script? (yes/no)"
read response

# Check the user's response
if [ "$response" = "yes" ]; then
    read -p "Enter network name " network
     
    echo "Continuing the script..."
    # Add your script logic here
else
    echo "Exiting the script."
    exit 0
fi

i=1

while true; do

    read -p "Enter additional ip (or 'exit' to quit): " input
     
     ip addr add $input dev $network:i
     i=$((i+1))
    if [[ $input == "exit" ]]; then
        echo "Exiting..."
        break
    fi

done

