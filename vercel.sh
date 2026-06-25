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

# Create the .env file because it is not pushed to GitHub
echo "Generating .env file..."
echo "SUPABASE_URL=https://jowrgsxsgxylqnymrzhr.supabase.co" > .env
echo "SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impvd3Jnc3hzZ3h5bHFueW1yemhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyNjAzNzcsImV4cCI6MjA5MjgzNjM3N30.qTl6sEh6PLhgxKQs7bEpnTAg_uOjDgpZ7fzv61zHdXA" >> .env

# Build the web app
echo "Building Flutter Web..."
flutter/bin/flutter config --enable-web
flutter/bin/flutter build web --release
