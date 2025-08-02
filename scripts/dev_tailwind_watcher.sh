#!/usr/bin/env bash

echo "🌼 [tailwind-watcher] Watching for changes using inotify..."
while true; do
  inotifywait -r -e modify,create,delete --exclude '\.swp$' assets/css
  echo "🌼 [tailwind-watcher] Change detected, rebuilding..."
  npx tailwindcss -i ./assets/css/app.css -o ./priv/static/assets/app.css
done

