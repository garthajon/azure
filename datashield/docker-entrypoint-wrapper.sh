#!/usr/bin/env bash

# if opal has not yet been initialised remove the srv folder
# and replace it with a link to the mnt folder, 
# this is so that configuration files and scripts created in initialisation and data
# will persist across container restarts and redeployments, as the mnt folder is a volume mount to an azure file share, and the srv folder is within the container filesystem and will not persist across restarts and redeployments
if [ ! -f "/mnt/.opal_initialised" ]; then
  echo "delete srv folder and create link to mnt folder for persistence across restarts and redeployments"
  # total removal of srv folder prior to creating the link to ensure that there are no issues with existing files or folders in the srv folder that could interfere with the linking process, and to ensure a clean setup for the initialisation of opal
  rm -rf /srv
  # rm = remove (delete files/directories)
  # -r = recursive (delete everything inside, including subfolders)
  # -f = force (no prompts, ignore errors)

  # this completely wipes /srv no confirmation, no undo if /srv contains important data (and isn’t mounted), it’s gone

  # create link as a shortcut to the mnt folder 
  ln -s /mnt /srv

  #ln = create a link
  #-s = symbolic link (a shortcut, like a pointer)

  #A symbolic link called /srv that points to /mnt/opal data. This means that when you access /srv, you are actually accessing /mnt/opaldata. Any files created in /srv will be stored in /mnt/opaldata, and any files in /mnt/opaldata will be accessible through /srv. This is useful for persisting data across container restarts, as the /mnt folder is a volume mount to an Azure file share, while the /srv folder is within the container filesystem and would not persist across restarts.

fi


# do not run the wrapper config if the .opal_initialised file exists in the /mnt folder
# as the exitence of this files indicates the container has already been configured and initialised
# note that the mnt folder is a volume mount within the container to an azure file share, so the .opal_initialised file will persist across container restarts and redeployments
if [ -f "/mnt/.opal_initialised" ]; then
  echo "opal is already initialised exit wrapper"

  # by not placing an ampersand at the end of this command
  # we ensure that the opal process becomes the foreground process and takes PID 1, 
  # which keeps the container alive and allows it to be managed properly by the container orchestrator, such as Kubernetes or Azure Container Instances
  # this line ensures the correct start up initiation of the opal server using the original entrypoint script provided in the opal docker image,
  # and it also ensures that the wrapper script does not run any of the customisation logic again, which is important to avoid potential issues with re-running configuration scripts on an already initialised opal instance
  # so the important thing here is that in the event that the container has already been configured
  # the wrapper is exited eloquently making the entrypoint script the foreground pid 1 process
  /usr/bin/bash /docker-entrypoint.sh app 
  #make the opal process pid 1 to keep the container alive
  # and exit the wrapper script to avoid running any of the customisation logic

  # i thought that exec opal was sufficient to start the opal container and keep it alive, 
  #but it seems that the original entrypoint script provided in the opal docker image is necessary to properly start the opal server, so we need to call the original entrypoint script directly to ensure the correct start up of the opal server, and we do not need to use exec opal here as the original entrypoint script will take care of starting the opal server and keeping it alive as the foreground process
 # exec opal
fi

echo "Runtime user: $(id -un) (uid=$(id -u), gid=$(id -g))"
# Start Opal using the original entrypoint
# defined in the opal docker repo source image
# set +e to avoid exiting on first error
echo "start docker-entrypoint.sh file up"
set +e

# check and print the bash version
which bash || echo "no bash"

# review current working directory contents
echo "PWD: $(pwd)"
echo "User: $(whoami)"
echo "current WORKDIR contents:"
ls -la

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

# Start the initialisation of Opal normally, this is usually for first time set up and configuration of Opal, but it will also run on subsequent restarts of the container if the .opal_initialised file is not found in the /mnt folder for any reason
/usr/bin/bash /docker-entrypoint.sh app &

echo "finished docker-entrypoint.sh file config"



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

# $! contains the PID of the last background process, which is the OPAL server we started earlier
# so we assign the process id for opal to a variable
OPAL_PID=$!

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
echo "PWD: $(pwd)"
echo "User: $(whoami)"
echo "current WORKDIR contents:"
ls -la

ls -la /mnt || echo "/mnt missing"
ls -la /srv/customise.sh  || echo "/srv/customise.sh missing"


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

if [ ! -f "/mnt/.opal_initialised" ]; then
  echo "CWD in customise.sh run attempt"
  /usr/bin/bash "/srv/customise.sh"
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



echo "PWD: $(pwd)"
echo "User: $(whoami)"
echo "current WORKDIR contents:"
ls -la


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


# re-enable exit on error
set -e


echo "finish customise.sh config"
# Keep container alive
wait $OPAL_PID
# make opal the foreground process to keep the container alive
# opal becomes PID 1
exec opal

