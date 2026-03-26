#!/usr/bin/env bash

trap shutdown_handler SIGTERM SIGINT

shutdown_handler() {
    echo "Shutdown signal received - final sync..."
    if [ -n "$OPAL_PID" ] && kill -0 "$OPAL_PID" 2>/dev/null; then
    kill "$OPAL_PID"
    wait "$OPAL_PID" || true
    fi
    rsync -a --delete --exclude 'tmlog*' /srv/ /mnt/opal/
}


#  Proper PID 1 wrapper model
# Wrapper stays alive
# Opal runs as child
# wait $OPAL_PID keeps container alive


#This is exactly what you want in Microsoft Azure for correct shutdown signal handling:

#Azure sends SIGTERM
#Wrapper catches it and 'forwards' it to Opal
#Opal shuts down cleanly
#Data sync to persistent storage happens after

FIRST_RUN=false
if [ ! -f /mnt/.initialised ]; then
    FIRST_RUN=true
fi

#########################################
# Pre-start logic
#########################################
if [ "$FIRST_RUN" = true ]; then
    echo "First run: cleaning mount"
    rm -rf /mnt/opal/* /mnt/opal/.[!.]* /mnt/opal/..?* || true
    # move to the root directory to avoid any potential issues with relative paths in the customise.sh script, as the script may expect to be run from the root directory of the container filesystem, and this also ensures that we are not in a subdirectory that could cause issues with file paths or permissions when running the customise.sh script, which is important for the correct execution of the configuration logic within that script
    cd /
    # Ensure mount exists
    mkdir -p /mnt/opal
else
    echo "Restoring persisted data"
    rm -rf /srv/*
    cp -r /mnt/opal/. /srv/
fi

#########################################
# Start Opal (ONLY ONCE)
#########################################
echo "Starting Opal..."
/usr/bin/bash /docker-entrypoint.sh app &
OPAL_PID=$!
set +e
#########################################
# First-run  (configure Opal)
#########################################
if [ "$FIRST_RUN" = true ]; then
    PORTS="8080"
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
          RESPONSE=$(curl -s -o /tmp/opal_response.json -w "%{http_code}" "$URL" || true)
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

    # $! contains the PID of the last background process, which is the OPAL server we started earlier
    # so we assign the process id for opal to a variable

    # At this point, OPAL is reachable, safe to run configuration scripts
    # bash /path/to/custom.sh

    cp /customise.sh /srv/customise.sh
    # Make it executable
    chmod +x /srv/customise.sh
    echo "finish customise.sh to srv folder"

    # run customise in foreground
    # but don't use exec and keep wrapper alive
    /usr/bin/bash "/srv/customise.sh"

    touch /mnt/.initialised
    #########################################
    # Wait for Opal (this keeps container alive)
    #########################################
fi
set -e
#########################################
# Shutdown handler
#########################################
# if azure sends sigterm wrapper gets it 
# so use opal pid to shutdown opal gracefully and then sync data to the mount



wait $OPAL_PID


# If OPAL exits naturally, run shutdown anyway
shutdown_handler
#exec /usr/bin/bash /docker-entrypoint.sh app &
#OPAL_PID=$!
#wait $OPAL_PID
#set +e














 


