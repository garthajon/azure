#!/usr/bin/env bash
set -e

echo "Starting Opal (supervisord)..."

/usr/bin/supervisord -c /etc/supervisor/supervisord.conf &

OPAL_PID=$!

echo "Waiting for Opal to become available..."

until curl -sf http://localhost:8080/ws/system/status > /dev/null; do
  echo "Opal not ready yet, sleeping..."
  sleep 10
done

echo "Opal is up."

# Run customisation only once
if [ ! -f /srv/.opal_initialised ]; then
  echo "Running Opal customisation..."
  /bin/bash /customise.sh
else
  echo "Opal already initialised, skipping customisation."
fi

# Bring Opal process to foreground
wait $OPAL_PID

