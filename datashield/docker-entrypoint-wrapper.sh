#!/usr/bin/env bash
set -e

# Start Opal using the original entrypoint
# defined in the opal docker repo source image
/bin/bash /docker-entrypoint.sh "$@" &

OPAL_PID=$!

# Wait for Opal
until curl -sf http://localhost:8080/ws/system/status > /dev/null; do
  sleep 10
done

# Run customisation once
if [ ! -f /srv/.opal_initialised ]; then
  /bin/bash /customise.sh
fi

# Keep container alive
wait $OPAL_PID
