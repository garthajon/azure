#!/usr/bin/env bash
echo "Runtime user: $(id -un) (uid=$(id -u), gid=$(id -g))"
# Start Opal using the original entrypoint
# defined in the opal docker repo source image
# set +e to avoid exiting on first error
echo "start docker-entrypoint.sh file up"
set +e
#/bin/bash /docker-entrypoint.sh "$@" &

# Start Opal normally
/bin/bash /docker-entrypoint.sh app &

echo "finished docker-entrypoint.sh file config"

OPAL_PID=$!

echo "start check opal up"
# Wait for Opal
until curl -sf http://localhost:8080/ws/system/status > /dev/null; do
  sleep 10
done

echo "finish check opal up"
# Run customisation once
echo "start customise.sh config"
if [ ! -f /mnt/.opal_initialised ]; then
  CWD="$(pwd)"

  if [ -x "$CWD/customise.sh" ] || [ -f "$CWD/customise.sh" ]; then
    /bin/bash "$CWD/customise.sh"
  else
    echo "ERROR: customise.sh not found in $CWD" >&2
    exit 1
  fi
fi


# re-enable exit on error
set -e


echo "finish customise.sh config"
# Keep container alive
wait $OPAL_PID
