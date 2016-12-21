#!/bin/bash -ex
# -e will fail the script if any command fails. It might be too constraining for some scripts
# -x echoes each command before running it. It can be disabled temporarily with 'set +x'.

PS4='\n+ Line ${LINENO}: ' # -x outputs is prefixed with newline and LINENO

BUILD_DIR=`pwd`
ZIP_2_5_0=~/Downloads/OpenDJ-2.5.0-Xpress1.zip
ZIP_2_6_0=~/Downloads/OpenDJ-2.6.0.zip
ZIP_3_0_0=~/Downloads/OpenDJ-3.0.0.zip
ZIP_3_5_0=~/Downloads/opendj-3.5.0.zip
ZIP_MASTER="${BUILD_DIR}/target/package/opendj-4.0.0-SNAPSHOT.zip"

ZIP=${ZIP_3_5_0}
ZIP2=${ZIP_MASTER}

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


echo
echo "##################################################################################################"
echo "# setting up OpenDJ in '$SETUP_DIR'"
echo "##################################################################################################"
rm -rf ${SETUP_DIR}
if [ -e ${SETUP_DIR}/config/archived-configs ]
then
    set +e
    rm ${SETUP_DIR}/config/archived-configs/*
    set -e
fi
if [ ! -e ${SETUP_DIR} ]
then
   mkdir -p ${SETUP_DIR}
   unzip -q ${ZIP} -d ${SETUP_DIR}
   if [ "${ZIP}" == "${ZIP_2_5_0}" ]
   then
      mv ${SETUP_DIR}/OpenDJ-2.5.0-Xpress1/* ${SETUP_DIR}
   else
      mv ${SETUP_DIR}/opendj/* ${SETUP_DIR}
   fi
fi

# TODO also clear $SETUP_DIR/.locks/*.lock ?

SETUP_ARGS="-d 1000"
if [ "{$ZIP}" != "${ZIP_2_5_0}" ]
then
    SETUP_ARGS="${SETUP_ARGS} --acceptLicense"
fi

# -O will prevent the server from starting
$SETUP_DIR/setup --cli -w "$PASSWORD" -p 1389 --adminConnectorPort "$ADMIN_PORT" -b "$BASE_DN" -n $SETUP_ARGS --enableStartTLS --generateSelfSignedCertificate --doNotStart -O #--acceptLicense
#--httpPort 8080

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
#read
#    $SETUP_DIR/bin/dsconfig create-local-db-vlv-index \
#          --hostname "${HOSTNAME}" -p "${ADMIN_PORT}" -D "${BIND_DN}" -w "${PASSWORD}" -X \
#          --backend-name userRoot \
#          --set base-dn:"$BASE_DN" \
#          --set filter:"(&(uid>=user.*)(photo>=*)(numSubordinates<=1)(entryUUID>=*)(modifyTimestamp>=0)(etag>=*)(internationaliSDNNumber>=*)(cn:en.1:=*)(cn:en.2:=*)(cn:en.3:=*)(cn:en.4:=*)(cn:en.5:=*)(relativeTimeGTOrderingMatch:=+5m)(relativeTimeLTOrderingMatch:=+5m))" \
#          --set scope:whole-subtree \
#          --set sort-order:"-uid photo numSubordinates entryUUID modifyTimestamp etag internationaliSDNNumber" \
#          --type generic \
#          --index-name upgrade_me \
#          --no-prompt
#read
# caseIgnoreMatch octetStringMatch integerOrderingMatch uuidOrderingMatch generalizedTimeOrderingMatch caseExactMatch 
# CaseIgnoreOrderingMatchingRule OctetStringOrderingMatchingRule IntegerOrderingMatchingRule UUIDOrderingMatchingRule GeneralizedTimeOrderingMatchingRule CaseExactOrderingMatchingRule NumericStringOrderingMatchingRule
# HistoricalCsnOrderingMatchingRule

#    $SETUP_DIR/bin/dsconfig create-backend-index \
#          --hostname "${HOSTNAME}" -p "${ADMIN_PORT}" -D "${BIND_DN}" -w "${PASSWORD}" -X \
#          --backend-name userRoot \
#          --set index-type:equality \
#          --type generic \
#          --index-name seealso \
#          --no-prompt

#    $SETUP_DIR/bin/rebuild-index -p "${ADMIN_PORT}" -D "${BIND_DN}" -w "${PASSWORD}" -X --baseDN "$BASE_DN" --index seealso

#target/package/opendj_auto/bin/ldapmodify -p 1389 -D "cn=Directory Manager" -w admin -a <<END_OF_COMMAND_INPUT
#dn: cn=A1,dc=example,dc=com
#objectclass:top
#objectclass:organizationalperson
#objectclass:inetorgperson
#objectclass:person
#sn:User
#cn:Test User
#userPassword:secret12
#description:1
#description:2
#seealso:cn=test
#mail:bla@example.com
#telephonenumber:+33165990803
#END_OF_COMMAND_INPUT

#    $SETUP_DIR/bin/ldapsearch -p 1389 -D "${BIND_DN}" -w "${PASSWORD}" -T -b "dc=example,dc=com" "(dn=user.999,ou=People,dc=example,dc=com)"

   $SETUP_DIR/bin/stop-ds

   unzip -q ${ZIP2} -d ${SETUP_DIR}
   rsync --archive ${SETUP_DIR}/opendj/ ${SETUP_DIR}

#read
    OPENDJ_JAVA_ARGS="-agentlib:jdwp=transport=dt_socket,address=${DEBUG_PORT},server=y,suspend=y" \
       $SETUP_DIR/upgrade -n --force

    OPENDJ_JAVA_ARGS="-agentlib:jdwp=transport=dt_socket,address=${DEBUG_PORT},server=y,suspend=n" \
       $SETUP_DIR/bin/start-ds

    $SETUP_DIR/bin/ldapsearch -p 1389 -D "${BIND_DN}" -w "${PASSWORD}" -T -b "dc=example,dc=com" "(dn=user.999,ou=People,dc=example,dc=com)"
fi

cd $BUILD_DIR
