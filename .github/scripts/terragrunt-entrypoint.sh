#!/usr/bin/env bash
set -euo pipefail

# Usage: terragrunt-entrypoint.sh <tenant> <region> <target> <mode>
# Example: terragrunt-entrypoint.sh SONAE northeurope foundation-lz plan
# Example: terragrunt-entrypoint.sh SONAE westeurope DigitalPP apply

# Parse arguments
TENANT="$1"
REGION="$2"
TARGET="$3" # bundle or stream name
MODE="$4"  # plan or apply

# # Configure SSH for private modules
# mkdir -p ~/.ssh
# eval "$(ssh-agent -s)"
# printf '%s\n' "$SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
# chmod 600 ~/.ssh/id_rsa
# ssh-add ~/.ssh/id_rsa
# ssh-keyscan github.com >> ~/.ssh/known_hosts

# Construct base directory path
BASE_DIR="tenants/$TENANT/vwan/$REGION"

# Determine the working directory and execution approach based on the target
if [[ "$TARGET" == "landingzone-complete" ]]; then
    # Deploy the entire landing zone with run-all
    WORKDIR="$BASE_DIR/LandingZone"
    echo "Executing $MODE for complete Landing Zone in $WORKDIR"
    
    cd "$WORKDIR"
    if [[ "$MODE" == "plan" ]]; then
        terragrunt run-all plan
    elif [[ "$MODE" == "apply" ]]; then
        terragrunt run-all apply -auto-approve
    else
        echo "Mode not supported: $MODE"
        exit 1
    fi
elif [[ "$TARGET" == "all-streams" ]]; then
    # Deploy all streams with run-all, which will automatically handle dependencies
    WORKDIR="$BASE_DIR/Stream"
    echo "Executing $MODE for all Streams in $WORKDIR"
    
    cd "$WORKDIR"
    if [[ "$MODE" == "plan" ]]; then
        terragrunt run-all plan
    elif [[ "$MODE" == "apply" ]]; then
        terragrunt run-all apply -auto-approve
    else
        echo "Mode not supported: $MODE"
        exit 1
    fi
elif [[ -d "$BASE_DIR/LandingZone/$TARGET" ]]; then
    # If target is a specific landing zone bundle
    WORKDIR="$BASE_DIR/LandingZone/$TARGET"
    echo "Executing $MODE for Landing Zone bundle: $TARGET in $WORKDIR"
    
    cd "$WORKDIR"
    if [[ "$MODE" == "plan" ]]; then
        terragrunt plan
    elif [[ "$MODE" == "apply" ]]; then
        terragrunt apply -auto-approve
    else
        echo "Mode not supported: $MODE"
        exit 1
    fi
elif [[ -d "$BASE_DIR/Stream/$TARGET" ]]; then
    # If target is a specific stream
    # Use run-all in the stream directory to automatically handle dependencies with the landing zone
    WORKDIR="$BASE_DIR/Stream/$TARGET/stream-lz"
    echo "Executing $MODE for Stream: $TARGET in $WORKDIR"
    
    cd "$WORKDIR"
    if [[ "$MODE" == "plan" ]]; then
        # Using --terragrunt-include-external-dependencies ensures LZ dependencies are included
        terragrunt plan --terragrunt-include-external-dependencies
    elif [[ "$MODE" == "apply" ]]; then
        # Using --terragrunt-include-external-dependencies ensures LZ dependencies are included
        terragrunt apply -auto-approve --terragrunt-include-external-dependencies
    else
        echo "Mode not supported: $MODE"
        exit 1
    fi
else
    echo "Target not recognized: $TARGET"
    exit 1
fi