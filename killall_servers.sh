#!/bin/bash -e

ps aux | grep java | grep .opends. | perl -ne 'print "$1\n" if (m/^\w+\+?\s+(\d+)/);' | xargs -r kill -9

RESULT=0
until [ "${RESULT}" != "" ]
do
    RESULT=`ps aux | grep java | grep .opends.`
    sleep 1
done

