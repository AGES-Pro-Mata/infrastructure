#!/bin/bash

# Load environment variables
source /home/ubuntu/.env

# Export all variables to make them available to docker stack deploy
export $(cat /home/ubuntu/.env | grep -v '^#' | xargs)

# Deploy the stack
docker stack deploy -c /home/ubuntu/dev-complete.yml promata-dev
