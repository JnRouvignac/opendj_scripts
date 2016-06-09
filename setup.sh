#!/bin/bash -ex
# -e will fail the script if any command fails. It might be too constraining for some scripts
# -x echoes each command before running it. It can be disabled temporarily with 'set +x'.

PS4='\n+ Line ${LINENO}: ' # -x outputs is prefixed with newline and LINENO

BUILD_DIR=`pwd`
PACKAGE_DIR="${BUILD_DIR}/target/package/opendj"
DATETIME=`date +%Y%m%d_%H%M%S`
SETUP_DIR="${PACKAGE_DIR}_auto"
HOSTNAME=localhost
ADMIN_PORT=4444
DEBUG_PORT=8000
BIND_DN="cn=Directory Manager"
PASSWORD=admin
BASE_DN="dc=example,dc=com"


echo "##################################################################################################"
echo "# stopping OpenDJ #"
echo "##################################################################################################"
if [ -e $SETUP_DIR ]
then
    set +e
    $SETUP_DIR/bin/stop-ds
    set -e
else
    echo "The setup dir '$SETUP_DIR' does not exist"
fi

rm -rf $SETUP_DIR
cp -r $PACKAGE_DIR $SETUP_DIR


echo
echo "##################################################################################################"
echo "# setting up OpenDJ in '$SETUP_DIR'"
echo "##################################################################################################"
if [ -e ${SETUP_DIR}/config/archived-configs ]
then
    set +e
    rm ${SETUP_DIR}/config/archived-configs/*
    set -e
fi
# TODO also clear $SETUP_DIR/.locks/*.lock ?

SETUP_ARGS="-d 1000"
#if [ -n "$DEBUG_PORT" ]
#then
#    SETUP_ARGS="$SETUP_ARGS -O"
#fi

# -O will prevent the server from starting
#OPENDJ_JAVA_ARGS="-agentlib:jdwp=transport=dt_socket,address=${DEBUG_PORT},server=y,suspend=n" \
$SETUP_DIR/setup --cli -w "$PASSWORD" -n -p 1389 --adminConnectorPort "$ADMIN_PORT" -b "$BASE_DN" $SETUP_ARGS --enableStartTLS --generateSelfSignedCertificate -O
#--httpPort 8080

# import initial data
#$SETUP_DIR/bin/import-ldif \
#        --backendID userRoot \
#        --ldifFile ~/ldif/Example.ldif \
#        --clearBackend \
#        -D "cn=Directory Manager" -w admin

if [ -n "$DEBUG_PORT" ]
then
    OPENDJ_JAVA_ARGS="-agentlib:jdwp=transport=dt_socket,address=${DEBUG_PORT},server=y,suspend=n" \
       $SETUP_DIR/bin/start-ds

    # start jdb on debug port to catch first debug session
    # then exit as fast as possible
    while true
    do
        echo exit
        sleep 0.1s
    done | jdb -attach localhost:$DEBUG_PORT
fi

cd $BUILD_DIR
