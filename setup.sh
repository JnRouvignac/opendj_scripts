#!/bin/bash -ex
# -e will fail the script if any command fails. It might be too constraining for some scripts
# -x echoes each command before running it. It can be disabled temporarily with 'set +x'.

PS4='\n+ Line ${LINENO}: ' # -x outputs is prefixed with newline and LINENO

BUILD_DIR=`pwd`
ZIP_2_5_0=~/git/pyforge/archives/OpenDJ-2.5.0-Xpress1.zip
ZIP_2_6_0=~/git/pyforge/archives/OpenDJ-2.6.0.zip
ZIP_3_0_0=~/git/pyforge/archives/OpenDJ-3.0.0.zip
ZIP_3_5_0=~/git/pyforge/archives/opendj-3.5.0.zip
ZIP_4_0_0=~/git/pyforge/archives/opendj-4.0.0.zip
ZIP_5_0_0=~/git/pyforge/archives/opendj-4.0.0.zip
ZIP_5_5_0=~/git/pyforge/archives/DS-5.5.0.zip
ZIP_6_0_0=~/git/pyforge/archives/DS-6.0.0.zip
ZIP_6_5_0=~/git/pyforge/archives/DS-6.5.0.zip
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
HOSTNAME=`hostname`
ADMIN_PORT=4444
DEBUG_PORT=8000
BIND_DN="uid=admin"
PASSWORD=password
BASE_DN="dc=example,dc=com"
DEPLOYMENT_KEY=AMsvM_0ZcFmWoyCizHo6SSuWIAFUxnA5CBVN1bkVDAMvhkJAzBthlHVs


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

USE_IMPORT=false
if [ "${USE_IMPORT}" = false ]
then
    SETUP_ARGS="--profile ds-evaluation --set generatedUsers:1000"
fi

if [ "${ZIP}" != "${ZIP_2_5_0}" ]
then
    SETUP_ARGS="${SETUP_ARGS} --acceptLicense"
fi


# OpenDJ < 4.0:
if [ "${BUILDING_35X}" = true ]
then
    SETUP_ARGS="$SETUP_ARGS --cli -n --acceptLicense" # --generateSelfSignedCertificate
fi
#OPENDJ_JAVA_ARGS="${OPENDJ_JAVA_ARGS} -agentlib:jdwp=transport=dt_socket,address=${DEBUG_PORT},server=y,suspend=n" \
$SETUP_DIR/setup -D "$BIND_DN" -w $PASSWORD \
                 --monitorUserPassword $PASSWORD \
                 --deploymentKey "$DEPLOYMENT_KEY" --deploymentKeyPassword $PASSWORD \
                 -h $HOSTNAME -p 1389 --adminConnectorPort "$ADMIN_PORT" \
                 $SETUP_ARGS \
                 --acceptLicense

if [ "${USE_IMPORT}" = true ]
then
    # import initial data
OPENDJ_JAVA_ARGS="${OPENDJ_JAVA_ARGS} -agentlib:jdwp=transport=dt_socket,address=${DEBUG_PORT},server=y,suspend=n" \
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
    OPENDJ_JAVA_ARGS="${OPENDJ_JAVA_ARGS} -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=~/git/opendj/opendj-server -agentlib:jdwp=transport=dt_socket,address=${DEBUG_PORT},server=y,suspend=n" \
       $SETUP_DIR/bin/start-ds

    # start jdb on debug port to catch first debug session
    # then exit as fast as possible
    while true
    do
        echo exit
        sleep 0.1s
    done | jdb -attach localhost:$DEBUG_PORT
fi


$SETUP_DIR/bin/dsconfig  -h $HOSTNAME -p "$ADMIN_PORT" -D "$BIND_DN" -w $PASSWORD --trustAll --no-prompt --batch <<END_OF_COMMAND_INPUT
                         create-connection-handler     --type http --handler-name "HTTP" --set enabled:true --set listen-port:8080
                         set-http-endpoint-prop        --endpoint-name /metrics/prometheus --set authorization-mechanism:HTTP\ Anonymous
                         set-http-endpoint-prop        --endpoint-name /metrics/api        --set authorization-mechanism:HTTP\ Anonymous
                         set-global-configuration-prop --set disabled-privilege:monitor-read
END_OF_COMMAND_INPUT


cd $BUILD_DIR
