#!/usr/bin/env bash

# This script is run by the opal container on startup.
# There are some values which are set as ENV VARS in the container which are set in opal-deployment.yaml
# The rest come from the values.yaml file.

# https://opaldoc.obiba.org/en/latest/python-user-guide/index.html

#checks to see if opal has already been initialised
# If it has then skip the customisation and exit
# this stops the customisation being run every time the container is restarted
# file check flag e checks whether the file exists at all, but does not check whether the file is a regular file or not
if [ -e /mnt/.opal_initialised ]; then
  echo "Opal already initialised skipping customisation"
  exit 0
fi


touch /doing_local_customisation.txt

# wget is not installed in the base docker image so add it here
apt update
apt install wget

# Check opal python client is installed
whereis opal

echo "Check opal has started before trying to add data etc"
until opal system --user administrator --password $OPAL_ADMINISTRATOR_PASSWORD --version
do
    echo "Customisation: Opal not up yet, sleeping..."
    sleep 30
done


# Most of these will just default to localhost

# Get the verion of opal
echo "Opal version:"
opal system --user administrator --password $OPAL_ADMINISTRATOR_PASSWORD --version

# Add the NORMAL DEMO_USER as defined in the docker_compose.yml file
opal user --user administrator --password $OPAL_ADMINISTRATOR_PASSWORD --add --name $OPAL_DEMO_USER_NAME --upassword $OPAL_DEMO_USER_PASSWORD

# Enable this user to be able to run DataSHIELD functions. Does not grant access to any data though.
opal perm-datashield --user administrator --password $OPAL_ADMINISTRATOR_PASSWORD --type USER --subject $OPAL_DEMO_USER_NAME --permission use --add

###########################################################################
# CNSIM DEMO DATA
###########################################################################

# Add a project
opal project --user administrator --password $OPAL_ADMINISTRATOR_PASSWORD --add --name $OPAL_DEMO_PROJECT --database mongodb
#opal project --user administrator --password $OPAL_ADMINISTRATOR_PASSWORD --add --name $OPAL_DEMO_PROJECT --database mysqldb

# Add the CNSIM1 data to the project
cd /tmp
mkdir opal-config-temp
cd opal-config-temp
pwd
wget $OPAL_DEMO_SOURCE_DATA_URL

opal_fs_path="/home/administrator"
opal_file_path="$opal_fs_path/`basename $OPAL_DEMO_SOURCE_DATA_URL`"

#uploads csv file into opal
opal file --user administrator --password $OPAL_ADMINISTRATOR_PASSWORD -up `basename $OPAL_DEMO_SOURCE_DATA_URL` $opal_fs_path

#create datasource in opal with the same name as the project, and specifies that the datasource is a mongodb datasource
opal create-datasource --user administrator --password $OPAL_ADMINISTRATOR_PASSWORD --name $OPAL_DEMO_PROJECT --type mongodb

#reads file from upload into datasource called "DEMO" i.e in this case the same name as the project defined by $OPAL_DEMO_PROJECT, with the table name defined by $OPAL_DEMO_TABLE, and specifies that the file is comma separated and that the value type for all variables is decimal
# note that the datasource name need not be the same as the project name, but in this case we are keeping it the same for simplicity
opal import-csv --user administrator --password $OPAL_ADMINISTRATOR_PASSWORD --destination $OPAL_DEMO_PROJECT --path $opal_file_path  --tables $OPAL_DEMO_TABLE --separator , --type Participant --valueType decimal

cd ..
rm -rf opal-config-temp

# Add permission to demo user to use the demo table, but not be able to see the data in the web interface.
opal perm-table --user administrator --password password --type USER --project $OPAL_DEMO_PROJECT --subject $OPAL_DEMO_USER_NAME --permission view --add --tables $OPAL_DEMO_TABLE


###########################################################################
# SYNTHEA DEMO DATA
###########################################################################

# Add a project
#opal project --user administrator --password $OPAL_ADMINISTRATOR_PASSWORD --add --name $OPAL_COHORT_PROJECT --database mongodb
##opal project --user administrator --password $OPAL_ADMINISTRATOR_PASSWORD --add --name $OPAL_COHORT_PROJECT --database mysqldb

# Add the COHORT data to the project
#cd /tmp
#mkdir opal-config-temp
#cd opal-config-temp
#pwd
#wget $OPAL_COHORT_SOURCE_DATA_URL

#opal_fs_path="/home/administrator"
#opal_file_path="$opal_fs_path/`basename $OPAL_COHORT_SOURCE_DATA_URL`"

#opal file --user administrator --password $OPAL_ADMINISTRATOR_PASSWORD -up `basename $OPAL_COHORT_SOURCE_DATA_URL` $opal_fs_path

#opal import-csv --user administrator --password $OPAL_ADMINISTRATOR_PASSWORD --destination $OPAL_COHORT_PROJECT --path $opal_file_path  --tables $OPAL_COHORT_TABLE --separator , --type Participant --valueType text

#cd ..
#rm -rf opal-config-temp

# Add permission to demo user to use the demo table, but not be able to see the data in the web interface.
#opal perm-table --user administrator --password password --type USER --project $OPAL_COHORT_PROJECT --subject $OPAL_DEMO_USER_NAME --permission view --add --tables $OPAL_COHORT_TABLE

touch /finished_local_customisation.txt

# Create a file to indicate that opal has been initialised
touch /mnt/.opal_initialised
