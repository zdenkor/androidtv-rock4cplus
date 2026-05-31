#!/bin/bash

# ============================================================================
# 03a-preinstall-apps.sh
# Pre-install application selection script
# ============================================================================

# Set script and work directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(dirname "$SCRIPT_DIR")"

# Detect BSP type from WORK_DIR
if [[ "$WORK_DIR" == *"radxa9"* ]]; then
    BSP_TYPE="radxa9"
elif [[ "$WORK_DIR" == *"vicharak12"* ]]; then
    BSP_TYPE="vicharak12"
elif [[ "$WORK_DIR" == *"aosp12"* ]]; then
    BSP_TYPE="aosp12"
else
    BSP_TYPE="unknown"
fi

# Define APPS_DIR
APPS_DIR="$WORK_DIR/apps"
SAVED_CHOICES_FILE="$APPS_DIR/.saved_choices"

# Check for saved choices
if [[ -f "$SAVED_CHOICES_FILE" ]]; then
    read -r -p "Saved choices found. Use them? (y/n): " use_saved
    if [[ "$use_saved" != "y" && "$use_saved" != "Y" ]]; then
        read -r -p "Enter app choices (1,2,3 or A/E/W): " APPS_CHOICES
    else
        APPS_CHOICES=$(cat "$SAVED_CHOICES_FILE")
    fi
else
    read -r -p "Enter app choices (1,2,3 or A/E/W): " APPS_CHOICES
fi

# Ensure choices were entered
if [[ -z "$APPS_CHOICES" ]]; then
    read -r -p "Enter app choices: " APPS_CHOICES
fi

# Save choices
echo "$APPS_CHOICES" > "$SAVED_CHOICES_FILE"

echo "Choices saved: $APPS_CHOICES"