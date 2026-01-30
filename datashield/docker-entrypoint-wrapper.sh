#!/usr/bin/env bash
echo "Runtime user: $(id -un) (uid=$(id -u), gid=$(id -g))"
# Start Opal using the original entrypoint
# defined in the opal docker repo source image
# set +e to avoid exiting on first error
echo "start docker-entrypoint.sh file up"
set +e

# review current working directory contents
echo "PWD: $(pwd)"
echo "User: $(whoami)"
echo "current WORKDIR contents:"
ls -la

#/bin/bash /docker-entrypoint.sh "$@" &
echo "start customise.sh to srv folder"
# nnote putting a forward slash before customise.sh
# explicitly means we are copying from the root directory of the build context
# to the /srv folder in the container
COPY /customise.sh /srv/customise.sh
RUN chmod +x /srv/customise.sh
echo "finish customise.sh to srv folder"

# Start Opal normally
/bin/bash /docker-entrypoint.sh app &

echo "finished docker-entrypoint.sh file config"

OPAL_PID=$!

echo "start check opal up"
# Wait for Opal
#until curl -sf http://localhost:8080/ws/system/status >/dev/null; do
#  sleep 10
#  echo "still stuck in a loop waiting for OPAL to start"
# done

#!/bin/sh

# List of ports to try
PORTS="8080 8443 8081"

# List of endpoints to try
ENDPOINTS="/ws/system/status /status /healthcheck /"

echo "Waiting for OPAL to become reachable..."

while :; do
  SUCCESS=0

  for PORT in $PORTS; do
    for ENDPOINT in $ENDPOINTS; do
      URL="http://localhost:${PORT}${ENDPOINT}"
      echo "Probing ${URL} ..."

      # Send request; capture body and exit code
      RESPONSE=$(curl -s -o /tmp/opal_response.json -w "%{http_code}" "$URL")
      RC=$?

      if [ "$RC" -eq 0 ]; then
        echo "SUCCESS: OPAL responded on ${URL}"
        echo "HTTP status code: ${RESPONSE}"
        echo "Response body (first 10 lines):"
        head -n 10 /tmp/opal_response.json
        SUCCESS=1
        break 2  # Exit both loops on first successful endpoint
      else
        echo "FAILED: No response from ${URL} (curl exit code ${RC})"
      fi
    done
  done

  if [ $SUCCESS -eq 1 ]; then
    echo "OPAL is reachable. Proceeding..."
    break
  fi

  echo "OPAL not reachable yet on any known port/endpoint. Sleeping 10s..."
  sleep 10
done

# At this point, OPAL is reachable, safe to run configuration scripts
# bash /path/to/custom.sh


echo "finish check opal up"
# Run customisation once
echo "start copying customise.sh file"
#cd /mnt
# we copy the customise.sh file from our repo to an absolute path /srv/customise.sh
# which should ensure that the file is definitely copied to the /srv folder in the container
RUN wget https://raw.githubusercontent.com/garthajon/azure/refs/heads/main/datashield/customise.sh -O /srv/customise.sh
RUN chmod +x /srv/customise.sh
# Make executable
#RUN chmod +x /customise.
echo "finished copying file start customise.sh config"

# review current working directory contents
echo "PWD: $(pwd)"
echo "User: $(whoami)"
echo "current WORKDIR contents:"
ls -la

if [ ! -f /mnt/.opal_initialised ]; then
  CWD="$(pwd)"

  if [ -x "$CWD/customise.sh" ] || [ -f "$CWD/customise.sh" ]; then
    /bin/bash "$CWD/customise.sh"
  else
    echo "ERROR: customise.sh not found in $CWD" >&2
    # when customise.sh is missing we should not exit with error
    # as this would try to restart the container endlessly
    # and the start up winds up in an infinite loop
    exit 0
  fi
fi


# re-enable exit on error
set -e


echo "finish customise.sh config"
# Keep container alive
wait $OPAL_PID
