#!/bin/bash

# Download Flutter
echo "Downloading Flutter..."
git clone https://github.com/flutter/flutter.git -b stable

# Add flutter to path
export PATH="$PATH:`pwd`/flutter/bin"

# Build the web app
echo "Building Flutter Web..."
flutter/bin/flutter config --enable-web
flutter/bin/flutter build web --release
