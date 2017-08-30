#!/bin/bash -ex
# -e will fail the script if any command fails. It might be too constraining for some scripts
# -x echoes each command before running it. It can be disabled temporarily with 'set +x'.

PS4='\n+ Line ${LINENO}: ' # -x outputs is prefixed with newline and LINENO

BUILD_DIR=`pwd`
ZIP_2_5_0=~/Downloads/OpenDJ-2.5.0-Xpress1.zip
ZIP_2_6_0=~/Downloads/OpenDJ-2.6.0.zip
ZIP_3_0_0=~/Downloads/OpenDJ-3.0.0.zip
ZIP_3_5_0=~/Downloads/opendj-3.5.0.zip
ZIP_4_0_0=~/Downloads/opendj-4.0.0.zip
BUILDING_35X=
if [ "${BUILDING_35X}" = false ]
then
    ZIP_MASTER=`ls ${BUILD_DIR}/target/package/*pen*-*.zip`
elif [ -z "${BUILDING_35X}" ]
then
    ZIP_MASTER=`ls ${BUILD_DIR}/target/*pen*-*.zip`
fi
ZIP=${ZIP_MASTER}

DATETIME=`date +%Y%m%d_%H%M%S`
SETUP_DIR="${BUILD_DIR}/target/opendj_auto"
HOSTNAME=localhost
ADMIN_PORT=4444
DEBUG_PORT=8000
BIND_DN="cn=Directory Manager"
PASSWORD=password
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
unzip -q ${ZIP} -d ${SETUP_DIR}
if [ "${ZIP}" == "${ZIP_2_5_0}" ]
then
   mv ${SETUP_DIR}/OpenDJ-2.5.0-Xpress1/* ${SETUP_DIR}
else
   mv ${SETUP_DIR}/opendj/* ${SETUP_DIR}
fi


echo
echo "##################################################################################################"
echo "# setting up OpenDJ in '$SETUP_DIR'"
echo "##################################################################################################"

USE_IMPORT=true
if [ "${USE_IMPORT}" = false ]
then
    SETUP_ARGS="-d 1000"
fi

if [ "${ZIP}" != "${ZIP_2_5_0}" ]
then
    SETUP_ARGS="${SETUP_ARGS} --acceptLicense"
fi


# -O will prevent the server from starting
# OpenDJ < 4.0:
if [ "${BUILDING_35X}" = true ]
then
    SETUP_ARGS="$SETUP_ARGS --cli -n --acceptLicense" # --generateSelfSignedCertificate
fi
#OPENDJ_JAVA_ARGS="-agentlib:jdwp=transport=dt_socket,address=${DEBUG_PORT},server=y,suspend=n" \
$SETUP_DIR/setup -h localhost -p 1389 -w "$PASSWORD" --adminConnectorPort "$ADMIN_PORT" -b "$BASE_DN" $SETUP_ARGS --enableStartTLS -O


if [ "${USE_IMPORT}" = true ]
then
    # import initial data
#OPENDJ_JAVA_ARGS="-agentlib:jdwp=transport=dt_socket,address=${DEBUG_PORT},server=y,suspend=y" \
    $SETUP_DIR/bin/import-ldif \
            --backendID userRoot \
            --ldifFile ~/ldif/Example.ldif \
            --clearBackend \
            --skipfile ${SETUP_DIR}/skipped --rejectfile ${SETUP_DIR}/rejected \
            --offline
#           -D "$BIND_DN" -w $PASSWORD
fi


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
