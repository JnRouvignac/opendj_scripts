#!/bin/bash -ex
# -e will fail the script if any command fails. It might be too constraining for some scripts
# -x echoes each command before running it. It can be disabled temporarily with 'set +x'.

PS4='\n+ Line ${LINENO}: ' # -x outputs is prefixed with newline and LINENO

DS_PIDS=`ps aux | grep java | grep DirectoryServer | perl -ne 'if (m@\S+\s+(\S+)@) {print "$1\n";}'`
JSTACKS_DIR=target/jstack

rm -rf $JSTACKS_DIR
mkdir -p $JSTACKS_DIR

for I in {1..30}
do
    JSTACK_PIDS=()
    for PID in $DS_PIDS
    do
        mkdir -p $JSTACKS_DIR/$PID
        jstack $PID > $JSTACKS_DIR/$PID/$I.txt &
        JSTACK_PIDS+=($!)
    done

    for PID in ${JSTACK_PIDS[*]}
    do
        wait $PID
    done
done

