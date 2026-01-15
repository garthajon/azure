#!/usr/bin/env bash

# Start Opal using the original entrypoint
# defined in the opal docker repo source image
# set +e to avoid exiting on first error
set +e
/bin/bash /docker-entrypoint.sh "$@" &

# re-enable exit on error
set -e

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
