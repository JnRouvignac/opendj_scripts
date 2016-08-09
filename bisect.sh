#!/bin/bash -x
# -e will fail the script if any command fails. It might be too constraining for some scripts
# -x echoes each command before running it. It can be disabled temporarily with 'set +x'.

PS4='\n+ Line ${LINENO}: ' # -x outputs is prefixed with newline and LINENO



# git bisect start BAD_COMMIT GOOD_COMMIT_1 [...  GOOD_COMMIT_N]

echo <<START_BISECT_SESSION

 git bisect start 98fa91eb1a7 e535e3f5281
 git bisect run ~/scripts/bisect.sh 2>&1 | tee bisect_out.txt

 # visualize the remaining suspects
 # git bisect view
 # review what has been done in this bisect session
 # git bisect log

START_BISECT_SESSION



run_pyforge()
{
    cd ~/git/pyforge
    if [ $? -ne 0 ]
    then
        exit 125 # stop bisecting
    fi

    ./run-pybot.py --suite testcases.replication.externalchangelog .
    FINAL_RESULT=$?

    cd -

    exit $FINAL_RESULT
}



run_setup_replication()
{
    cd ~/git/opendj/opendj-server-legacy
    if [ $? -ne 0 ]
    then
        exit 125 # stop bisecting
    fi

    ~/scripts/setup_replication.sh
    FINAL_RESULT=$?

    cd -

    exit $FINAL_RESULT
}


#####################
# EXECUTE bisect.sh #
#####################

~/scripts/killall_servers.sh;

mvn clean install -Dmaven.test.skip;
if [ $? -ne 0 ]
then
    exit 125 # skip revision
fi

run_setup_replication

