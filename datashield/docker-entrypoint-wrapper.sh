#!/usr/bin/env bash
#!/bin/bash
# clear temp locks
rm -rf /tmp/*
# wipe the mount on first deployment 
if [ ! -f /mnt/.initialised ]; then
    echo "First deployment - clearing mount..."
    cd /
    rm -rf /mnt/opal/* /mnt/opal/.[!.]* /mnt/opal/..?*
else
    echo "Mount already initialised - skipping wipe"
fi

# First run: no persisted data
if [ ! -d /mnt/opal/data ]; then
    echo "First run: using local /srv"

    cd /
    echo "Cleaning Atomikos logs..."
    find /srv -name "tmlog*" -exec rm -rf {} + 2>/dev/null || true

    # Start Opal normally (local /srv)
    # and then return to/carry on with the main wrapper script - this is what the ampersand is for 
    /usr/bin/bash /docker-entrypoint.sh app &

    # Wait for setup to complete (you may need a better check)
    sleep 30
    
    echo "finished docker-entrypoint.sh file config"

else
    echo "Subsequent run: using persisted data"

    # Replace /srv with persisted data from the mounted volume
    # if this is a container restart
    # move to the root directory to avoid any potential issues with relative paths in the customise.sh script, as the script may expect to be run from the root directory of the container filesystem, and this also ensures that we are not in a subdirectory that could cause issues with file paths or permissions when running the customise.sh script, which is important for the correct execution of the configuration logic within that script
    cd /
    rm -rf /srv
    cp -r /mnt/opal/. /srv/
    find /srv -name "tmlog*" -exec rm -rf {} + 2>/dev/null || true

    # since this is a restart, ensure the sync loop is running 
    
    #########################################
    # Background sync function
    #########################################

    #sync_loop() {
    #    while true; do
    #        echo "Syncing /srv -> /mnt/opal..."
    #        # exclude tmlog files from the sync to avoid potential issues with file locks and concurrent access to log files by both the opal server and the rsync process, which could cause errors or performance issues, and since log files are typically not critical for the persistent storage of the opal data and settings, excluding them from the sync should not cause any issues with data integrity or loss of important information, while also improving the stability and performance of the sync process
    #        rsync -a --delete --exclude 'tmlog*' /srv/ /mnt/opal/
    #        #rsync -a --delete /srv/ /mnt/opal/
    #        sleep 300   # every 5 minutes (adjust if needed)
    #    done
    #}

    #########################################
    # Shutdown handler
    #########################################
    shutdown_handler() {
        echo "Shutdown signal received - final sync..."
       # rsync -a --delete /srv/ /mnt/opal/
        rsync -a --delete --exclude 'tmlog*' /srv/ /mnt/opal/
        find /srv -name "tmlog*" -exec rm -rf {} + 2>/dev/null || true
        echo "Final sync complete"
    }

    trap shutdown_handler SIGTERM SIGINT

    #########################################
    # Start background sync
    #########################################
    #sync_loop &


    # Start Opal using local filesystem again
    # note that the control flow will not now return to the wrapper script after this point as we are not using an ampersand to run the entrypoint script in the background, so the entrypoint script will become the foreground process and take PID 1, which is important for proper container management and lifecycle handling by the container orchestrator, such as Kubernetes or Azure Container Instances
    # this starts the container up with the local /srv directory
    # and this exits the wrapper script
    # hence this section runs for subsequent restarts of the container
    # even here the start up should run as a wrapper process 
    exec /usr/bin/bash /docker-entrypoint.sh app &
    OPAL_PID=$!
    wait $OPAL_PID
fi


# do not run the wrapper config if the .opal_initialised file exists in the /mnt folder
# as the exitence of this files indicates the container has already been configured and initialised
# note that the mnt folder is a volume mount within the container to an azure file share, so the .opal_initialised file will persist across container restarts and redeployments
#if [ -f "/mnt/.opal_initialised" ]; then
 # echo "opal is already initialised exit wrapper"

  # by not placing an ampersand at the end of this command
  # we ensure that the opal process becomes the foreground process and takes PID 1, 
  # which keeps the container alive and allows it to be managed properly by the container orchestrator, such as Kubernetes or Azure Container Instances
  # this line ensures the correct start up initiation of the opal server using the original entrypoint script provided in the opal docker image,
  # and it also ensures that the wrapper script does not run any of the customisation logic again, which is important to avoid potential issues with re-running configuration scripts on an already initialised opal instance
  # so the important thing here is that in the event that the container has already been configured
  # the wrapper is exited eloquently making the entrypoint script the foreground pid 1 process
#  /usr/bin/bash /docker-entrypoint.sh app 
  #make the opal process pid 1 to keep the container alive
  # and exit the wrapper script to avoid running any of the customisation logic

  # i thought that exec opal was sufficient to start the opal container and keep it alive, 
  #but it seems that the original entrypoint script provided in the opal docker image is necessary to properly start the opal server, so we need to call the original entrypoint script directly to ensure the correct start up of the opal server, and we do not need to use exec opal here as the original entrypoint script will take care of starting the opal server and keeping it alive as the foreground process
 # exec opal
#fi

# even if opal has  been initialsed we should still run  /usr/bin/bash /docker-entrypoint.sh app 
# because this is equivalent to a 'boot' script to start opal up properly 
# and this is what that script does - 
# Starts required services
# Initializes runtime config
# Connects to MongoDB
# Launches the Opal application


#echo "Runtime user: $(id -un) (uid=$(id -u), gid=$(id -g))"
# Start Opal using the original entrypoint
# defined in the opal docker repo source image
# set +e to avoid exiting on first error
#echo "start docker-entrypoint.sh file up"
if [ ! -f /mnt/.initialised ]; then
    set +e

# check and print the bash version
#which bash || echo "no bash"

# review current working directory contents
#echo "PWD: $(pwd)"
#echo "User: $(whoami)"
#echo "current WORKDIR contents:"
#ls -la

#/bin/bash /docker-entrypoint.sh "$@" &
    echo "start customise.sh to srv folder"
# note putting a forward slash before customise.sh
# explicitly means we are copying from the root directory of the build context
# to the /srv folder in the container
# Copy the script inside the container filesystem
# replace invalid docker buildcontext runtime copy commands with
# valid shell commands
    cp /customise.sh /srv/customise.sh
# Make it executable
    chmod +x /srv/customise.sh
    echo "finish customise.sh to srv folder"

# Start the initialisation of Opal normally and then continue with the wrapper script in order to run set up
# this will only ever run for first time start up
    /usr/bin/bash /docker-entrypoint.sh app &
# capture the PID id of the opal container startup process now running in the background
    OPAL_PID=$!


    echo "start check opal up"
    # Wait for Opal
    #until curl -sf http://localhost:8080/ws/system/status >/dev/null; do
    #  sleep 10
    #  echo "still stuck in a loop waiting for OPAL to start"
    # done

    #!/bin/sh

    # List of ports to try
    #PORTS="8080 8443 8081"
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

    # $! contains the PID of the last background process, which is the OPAL server we started earlier
    # so we assign the process id for opal to a variable


    # At this point, OPAL is reachable, safe to run configuration scripts
    # bash /path/to/custom.sh


    echo "finish check opal up"
    # Run customisation once
    #echo "start copying customise.sh file"
    #cd /mnt
    # we copy the customise.sh file from our repo to an absolute path /srv/customise.sh
    # which should ensure that the file is definitely copied to the /srv folder in the container
    #'RUN wget https://raw.githubusercontent.com/garthajon/azure/refs/heads/main/datashield/customise.sh -O /srv/customise.sh
    #RUN chmod +x /srv/customise.sh
    # Make executable
    #RUN chmod +x /customise.
    #echo "finished copying file start customise.sh config"

    # review current working directory contents
    #echo "PWD: $(pwd)"
    #echo "User: $(whoami)"
    #echo "current WORKDIR contents:"
    #ls -la

    #ls -la /mnt || echo "/mnt missing"
    #ls -la /srv/customise.sh  || echo "/srv/customise.sh missing"


    #if [ ! -f /mnt/.opal_initialised ]; then

    # until the opal container can talk to the mongo container we should not try to run the customise.sh script

    # nc is not installed in the base docker image so add it here

    #apt-get update && apt-get install -y netcat-openbsd

    #apt-get update
    #apt-get install -y mongodb-mongosh


    #MONGO_HOST="mongodb"
    #MONGO_PORT="27017"

    #echo "Checking MongoDB availability..."


    #mongosh "mongodb://user:pass@mongo:27017/?authSource=admin"

    #until mongosh "mongodb://user:pass@mongo:27017/?authSource=admin"; do
    # echo "MongoDB not available yet — retrying..."
    #  sleep 2
    #done

    #until nc -z "$MONGO_HOST" "$MONGO_PORT"; do
    #  echo "MongoDB not available yet — retrying..."
    #  sleep 2
    #done

      #echo "MongoDB is reachable."
    echo "CWD in customise.sh run attempt"
    # this should also run as a background process and leave the wrapper running 
    /usr/bin/bash "/srv/customise.sh" &

  # re-enable exit on error
    set -e

    # move to the root directory to avoid any potential issues with relative paths in the customise.sh script, as the script may expect to be run from the root directory of the container filesystem, and this also ensures that we are not in a subdirectory that could cause issues with file paths or permissions when running the customise.sh script, which is important for the correct execution of the configuration logic within that script
    cd /

    # Ensure mount exists
    mkdir -p /mnt/opal
    # Copy  set up data to persistent storage
    #cp -r /srv/* /mnt/opal/
    rsync -a --delete --exclude 'tmlog*' /srv/ /mnt/opal/
    find /srv -name "tmlog*" -exec rm -rf {} + 2>/dev/null || true

    echo "finish customise.sh config"
fi


# the -e flag checks whether the file exists at all
# it does not check whether the file is a regular file or not
#if [ -e /mnt/.opal_initialised ]; then
#    echo "File exists, e flag file check"
#    /usr/bin/bash "/srv/customise.sh"
#else
#    echo "File does not exist e flag file check"
#fi


#if ls -l /mnt/.opal_initialised >/dev/null 2>&1; then
#    echo "File exists - ls file check"
#    /usr/bin/bash "/srv/customise.sh"
#else
#    echo "File does not exist - ls file check"
#fi




#if [ ! -f /mnt/.opal_initialised ]; then
#  CWD="$(pwd)"
## add initial forward slash to ensure abolute reference for executing the customise.sh file
#  if [ -x "/$CWD/customise.sh" ] || [ -f "/$CWD/customise.sh" ]; then
#    echo "CWD in customise.sh run attempt: $CWD"
#    /bin/bash "/$CWD/customise.sh"
#  else
#    echo "ERROR: customise.sh not found in $CWD" >&2
#    # when customise.sh is missing we should not exit with error
#    # as this would try to restart the container endlessly
#    # and the start up winds up in an infinite loop
#    exit 0
#  fi
#fi




#########################################
# Background sync function - to ensure SRC back up on the mount and live SRC are synced
#########################################
#sync_loop() {
#    while true; do
#        echo "Syncing /srv -> /mnt/opal..."
#        #rsync -a --delete /srv/ /mnt/opal/
#        rsync -a --delete --exclude 'tmlog*' /srv/ /mnt/opal/
#        sleep 300   # every 5 minutes (adjust if needed)
#    done
#}

#########################################
# Shutdown handler - ensure SRC is synced to the mount on shutdown to avoid data/settinngs loss
#########################################
shutdown_handler() {
    echo "Shutdown signal received - final sync..."
    #rsync -a --delete /srv/ /mnt/opal/
    rsync -a --delete --exclude 'tmlog*' /srv/ /mnt/opal/
    find /srv -name "tmlog*" -exec rm -rf {} + 2>/dev/null || true
    echo "Final sync complete"
}

trap shutdown_handler SIGTERM SIGINT

#########################################
# Start background sync
#########################################
#sync_loop &
# Keep container alive

# make opal the foreground process to keep the container alive
# opal becomes PID 1
# but sync loop is still running in the background to ensure data is synced to the persistent storage every 5 minutes and on shutdown
# not ideal but its a workaround pending a better solution to ensure the SRC directory is used persistently  and data/settings are not lost on container restarts and redeployments, 
# which is a key requirement for our use case of running opal in a containerised environment with an azure file share as the persistent storage solution for the opal data and settings
# its the permissions on the azure file share that is causing the big issue here

# OPAL cannot be PID 1 because we are using a wrapper
# so do not use 'exec opal' which would make it pid 1 but rather leave it running in the 
# backgroun
#exec opal

# this effectively says 'stay inside this wrapper script until the opal process is finished'
# but as the wrapper is PID 1, this basically keeps the wrapper script running
# and therefore indirectly the container running as a background process 
# the wait instruction in the wrapper keeps the container alive 
# and also the wrapper running
wait $OPAL_PID

 


