#!/usr/bin/env bash
set -e

echo "Starting Opal..."
/entrypoint.sh &

echo "Waiting for Opal..."
until opal system --user administrator --password "$OPAL_ADMINISTRATOR_PASSWORD" --version >/dev/null 2>&1
do
  sleep 10
done

echo "Running customisation..."
/customise.sh

wait
echo "Exiting docker-entrypoint.sh"