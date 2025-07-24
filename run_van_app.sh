#!/bin/bash

# Print header
echo "===================================="
echo "Van Damage Tracker App Launcher"
echo "===================================="

# Run the van merging script if it exists
echo "Checking for duplicate van entries..."
if [ -f "/Users/prolix/7/merge_vans.py" ]; then
  echo "Running merge_vans.py to consolidate duplicate van entries..."
  cd /Users/prolix/7 && python3 merge_vans.py
  echo "Van entries merged successfully!"
else
  echo "Note: merge_vans.py not found - skipping van consolidation"
fi

# Navigate to the project directory
echo "Navigating to project directory..."
cd /Users/prolix/7/van_damage_tracker || {
  echo "Error: Could not navigate to project directory"
  exit 1
}

# Make sure we have web support
echo "Ensuring web support is enabled..."
flutter config --enable-web
flutter create --platforms=web . > /dev/null 2>&1

# Run the Flutter app in Chrome
echo "Launching app in Chrome..."
echo "===================================="
flutter run -d chrome

# This will keep the terminal open if the app crashes
echo "App has exited. Press any key to close this window."
read -n 1 