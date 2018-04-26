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
BASE_DIR="target"
SERVER_PID_FILE="logs/server.pid"
HOSTNAME=localhost
BIND_DN="cn=Directory Manager"
PASSWORD=password
BASE_DN="dc=example,dc=com"
# Naming is important here:
# DS   means: deploy a DS only node
#   RS means: deploy a RS only node
# DSRS means: deploy a combined DS-RS node
REPLICA_DIRS=( \
               opendj_0_DSRS \
               opendj_1_DSRS \
             )
DEBUG_TARGETS=( \
#org.opends.server.replication.server.ReplicationServerDomain \
#org.opends.server.replication.service.ReplicationBroker \
#org.opends.server.replication.service.ReplicationDomain \
#org.opends.server.replication.protocol.Session \
              )
TOPOLOGY_TRUSTSTORE=target/replication_topology_truststore



rm -rf $BASE_DIR/opendj_*
rm  -f $TOPOLOGY_TRUSTSTORE

DIR="$BASE_DIR/${REPLICA_DIRS[0]}"
unset IS_DSRS
unset IS_DS_ONLY
unset IS_RS_ONLY
unset IS_DS
unset IS_RS

if [[ "$DIR" == *DSRS* ]]
then
    IS_DSRS=1
    IS_DS=1
    IS_RS=1
elif [[ "$DIR" == *DS* ]]
then
    IS_DS_ONLY=1
    IS_DS=1
elif [[ "$DIR" == *RS* ]]
then
    IS_RS_ONLY=1
    IS_RS=1
fi

DSREPLICATION_ENABLE_ARGS_0=""
if [ -n "${IS_DS_ONLY}" ]
then
    DSREPLICATION_ENABLE_ARGS_0="${DSREPLICATION_ENABLE_ARGS_0} --noReplicationServer1"
elif [ -n "${IS_RS}" ]
then
    DSREPLICATION_ENABLE_ARGS_0="${DSREPLICATION_ENABLE_ARGS_0} --replicationPort1 8900"
    if [ -n "${IS_RS_ONLY}" ]
    then
        DSREPLICATION_ENABLE_ARGS_0="${DSREPLICATION_ENABLE_ARGS_0} --onlyReplicationServer1"
    fi
fi

NB_DS=0
for IDX in ${!REPLICA_DIRS[*]}
do
    DIR="$BASE_DIR/${REPLICA_DIRS[$IDX]}"
    unset IS_DSRS
    unset IS_DS_ONLY
    unset IS_RS_ONLY
    unset IS_DS
    unset IS_RS

    if [[ "$DIR" == *DSRS* ]]
    then
        IS_DSRS=1
        IS_DS=1
        IS_RS=1
        NB_DS=$(($NB_DS + 1))
    elif [[ "$DIR" == *DS* ]]
    then
        IS_DS_ONLY=1
        IS_DS=1
        NB_DS=$(($NB_DS + 1))
    elif [[ "$DIR" == *RS* ]]
    then
        IS_RS_ONLY=1
        IS_RS=1
    fi

    ###################################
    # Stop/Kill previous server
    ###################################
    if [ -e "$DIR" ]
    then
        echo
        echo "##################################################################################################"
        echo "# Stopping server $DIR"
        echo "##################################################################################################"
        $DIR/bin/stop-ds
        if [ -e $SERVER_PID_FILE ]
        then
            SERVER_PID=`cat $SERVER_PID_FILE`
            # temporarily disable stop on error then reenable again
            set +e
            kill -KILL $SERVER_PID
            set -e
        fi

        rm -rf $DIR
    fi
    unzip -q ${ZIP} -d ${DIR}
    if [ "${ZIP}" == "${ZIP_2_5_0}" ]
    then
        mv ${DIR}/OpenDJ-2.5.0-Xpress1/* ${DIR}
    else
        mv ${DIR}/opendj/* ${DIR}
    fi


    ###################################
    # Setup
    ###################################
    echo
    echo "##################################################################################################"
    echo "# Setting up and starting server $DIR, debugging on port 800$IDX"
    echo "##################################################################################################"
    SETUP_ARGS=""
    if [ -n ${IS_DS} ]
    then
        # import initial data
        # $DIR/bin/import-ldif \
        #              --backendID userRoot \
        #              --ldifFile ~/ldif/Example.ldif \
        #              --clearBackend
        #              # -D "cn=Directory Manager" -w admin
        if [ -z "${DATA_INITIALIZED}" ]
        then
            SETUP_ARGS="$SETUP_ARGS -d 1000"
            DATA_INITIALIZED=1
        fi

        SETUP_ARGS="$SETUP_ARGS -b $BASE_DN"
    elif [ -n ${IS_RS} ]
    then
        : # empty for now
    fi

    # OpenDJ < 4.0:
    if [ "${BUILDING_35X}" = true ]
    then
        SETUP_ARGS="$SETUP_ARGS --cli -n --acceptLicense" # --generateSelfSignedCertificate
    fi
    $DIR/setup -D "$BIND_DN" -w $PASSWORD -p 150$IDX -h $HOSTNAME --adminConnectorPort 450$IDX  $SETUP_ARGS  -O

    if [ -z "${BUILDING_35X}" ]
    then
        rm -f $DIR/rs$IDX.cert
        # export certificate from server
        keytool -exportcert -alias server-cert -keystore $DIR/config/keystore -storetype pkcs12 -storepass:file $DIR/config/keystore.pin -file $DIR/rs$IDX.cert
        # import certificate from the server into the topology truststore
        keytool -importcert -noprompt -keystore $TOPOLOGY_TRUSTSTORE -keypass $PASSWORD -storepass password -storetype jks -alias rs$IDX-cert -file $DIR/rs$IDX.cert
    fi

    OPENDJ_JAVA_ARGS="${OPENDJ_JAVA_ARGS} -agentlib:jdwp=transport=dt_socket,address=800$IDX,server=y,suspend=n" $DIR/bin/start-ds
    # OPENDJ_JAVA_ARGS="${OPENDJ_JAVA_ARGS} -Djavax.net.debug=all" # For SSL debug

    # add proxy-auth privilege
    # enable combined logs
    # keep only 1 file for logs/access to avoid staturating the disk
    $DIR/bin/dsconfig     -h $HOSTNAME -p 450$IDX -D "$BIND_DN" -w $PASSWORD --trustAll --no-prompt --batch <<END_OF_COMMAND_INPUT
                          set-root-dn-prop               --add default-root-privilege-name:proxied-auth
                          set-log-publisher-prop        --publisher-name "File-Based Access Logger" --set log-format:combined
                          set-log-retention-policy-prop --policy-name "File Count Retention Policy" --set number-of-files:1
END_OF_COMMAND_INPUT

    # enable debug logs + create debug targets
#    $DIR/bin/dsconfig -h $HOSTNAME -p 450$IDX -D "$BIND_DN" -w $PASSWORD --trustAll --no-prompt \
#                      set-log-publisher-prop        --publisher-name "File-Based Debug Logger" --set enabled:true --set default-debug-level:disabled
#    for CLAZZ in ${DEBUG_TARGETS}
#    do
#        $DIR/bin/dsconfig -h $HOSTNAME -p 450$IDX -D "$BIND_DN" -w $PASSWORD --trustAll --no-prompt \
#                          create-debug-target        --publisher-name "File-Based Debug Logger" --set debug-level:all --set include-throwable-cause:true --type generic --target-name $CLAZZ
#    done

    if [ -n "${DEBUG_TARGETS}"  -a  ${#DEBUG_TARGETS[@]} -ne 0 ]
    then
        # need to restart the server for the debug log changes to take effect. @see OPENDJ-1289
        $DIR/bin/stop-ds
        sleep 2
        OPENDJ_JAVA_ARGS="${OPENDJ_JAVA_ARGS} -agentlib:jdwp=transport=dt_socket,address=800$IDX,server=y,suspend=n" $DIR/bin/start-ds
    fi


    ###################################
    # Replication
    ###################################
    if [ ${IDX} -ne 0 ]
    then
        DSREPLICATION_ENABLE_ARGS=""
        if [ -n "${IS_DS_ONLY}" ]
        then
            DSREPLICATION_ENABLE_ARGS="${DSREPLICATION_ENABLE_ARGS} --noReplicationServer2"
        elif [ -n "${IS_RS}" ]
        then
            DSREPLICATION_ENABLE_ARGS="${DSREPLICATION_ENABLE_ARGS} --replicationPort2 890$IDX"
            if [ -n "${IS_RS_ONLY}" ]
            then
                DSREPLICATION_ENABLE_ARGS="${DSREPLICATION_ENABLE_ARGS} --onlyReplicationServer2"
            fi
        fi

        echo
        echo "##################################################################################################"
        echo "# Creating replication link: ${REPLICA_DIRS[0]} => ${REPLICA_DIRS[$IDX]}"
        echo "##################################################################################################"
#OPENDJ_JAVA_ARGS="${OPENDJ_JAVA_ARGS} -agentlib:jdwp=transport=dt_socket,address=8003,server=y,suspend=y" \
        $DIR/bin/dsreplication configure \
                 --adminUID admin --adminPassword $PASSWORD --baseDN "$BASE_DN" --trustAll --no-prompt \
                 --host1 $HOSTNAME     --port1 4500    --bindDN1 "$BIND_DN" --bindPassword1 $PASSWORD $DSREPLICATION_ENABLE_ARGS_0 \
                 --host2 $HOSTNAME     --port2 450$IDX --bindDN2 "$BIND_DN" --bindPassword2 $PASSWORD $DSREPLICATION_ENABLE_ARGS
        echo "Done."

        echo
        echo "##################################################################################################"
        echo "# Setting replication group #$IDX for ${REPLICA_DIRS[$IDX]}"
        echo "##################################################################################################"
        if [ -n "${IS_RS}" ]
        then
            $DIR/bin/dsconfig -h $HOSTNAME -p 450$IDX -D "$BIND_DN" -w $PASSWORD --trustAll --no-prompt \
                              set-replication-server-prop   --provider-name "Multimaster Synchronization" --set group-id:$IDX
        fi
        if [ -n "${IS_DS}" ]
        then
            $DIR/bin/dsconfig -h $HOSTNAME -p 450$IDX -D "$BIND_DN" -w $PASSWORD --trustAll --no-prompt \
                              set-replication-domain-prop   --provider-name "Multimaster Synchronization" --set group-id:$IDX  --domain-name dc=example,dc=com
        fi

        echo "Done."
    fi
done

if [ -z "${BUILDING_35X}" ]
then
    keytool -list -keystore $TOPOLOGY_TRUSTSTORE -storepass $PASSWORD
fi

# let last node finish startup
sleep 10

echo
echo "##################################################################################################"
echo "# Initializing replication"
echo "##################################################################################################"
IDX=0
DIR="$BASE_DIR/${REPLICA_DIRS[$IDX]}"

if [ ${NB_DS} -gt 1 ]
then
    # Next command is only useful when there is more than one DS
#OPENDJ_JAVA_ARGS="${OPENDJ_JAVA_ARGS} -agentlib:jdwp=transport=dt_socket,address=8003,server=y,suspend=y" \
    $DIR/bin/dsreplication    initialize-all --adminUID admin  -w $PASSWORD \
                         -h $HOSTNAME -p 450$IDX -b "$BASE_DN" --trustAll --no-prompt
fi

exit

#/home/jnrouvignac/git/opendj/opendj-server/target/opendj/setup proxy-server \
#          --instancePath /home/jnrouvignac/git/opendj/opendj-server/target/opendj \
#          --rootUserDn cn=Directory\ Manager \
#          --rootUserPassword ****** \
#          --hostname jnrouvignac-Precision-5510 \
#          --adminConnectorPort 4444 \
#          --ldapPort 1389 \
#          --enableStartTls \
#          --ldapsPort 1636 \
#          --httpsPort 8443 \
#          --staticPrimaryServer localhost:1500 \
#          --staticPrimaryServer localhost:1501 \
#          --proxyUserBindDn cn=Directory\ Manager \
#          --proxyUserBindPassword ****** \
#          --loadBalancingAlgorithm affinity

$DIR/bin/dsconfig     -h $HOSTNAME -p 4500 -D "$BIND_DN" -w $PASSWORD --trustAll --no-prompt --batch <<END_OF_COMMAND_INPUT
                              delete-backend                     --backend-name userRoot
                              set-trust-manager-provider-prop    --provider-name "Blind Trust" --set enabled:true
                              create-service-discovery-mechanism --type replication --mechanism-name replication-service  --set replication-server:$HOSTNAME:1501 --set "trust-manager-provider:Blind Trust" \
                                                                 --set bind-dn:"$BIND_DN" --set bind-password:$PASSWORD
                              create-service-discovery-mechanism --type static      --mechanism-name static-service \
                                                                 --set primary-server:$HOSTNAME:1501  --set primary-server:$HOSTNAME:1502
                              create-backend                     --type proxy       --backend-name proxy  --set enabled:true \
                                                                 --set proxy-user-dn:"$BIND_DN" --set proxy-user-password:$PASSWORD --set route-all:true --set service-discovery-mechanism:replication-service
END_OF_COMMAND_INPUT

