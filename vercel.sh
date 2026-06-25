#!/bin/bash

# Download Flutter
echo "Checking for Flutter..."
if [ -d "flutter" ]; then
  echo "Flutter is already installed!"
else
  echo "Downloading Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable
fi

# Add flutter to path
export PATH="$PATH:`pwd`/flutter/bin"

# Build the web app
echo "Building Flutter Web..."
flutter/bin/flutter config --enable-web
flutter/bin/flutter build web --release
