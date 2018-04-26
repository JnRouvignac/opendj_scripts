#!/bin/bash -ex
# -e will fail the script if any command fails. It might be too constraining for some scripts
# -x echoes each command before running it. It can be disabled temporarily with 'set +x'.

PS4='\n+ Line ${LINENO}: ' # -x outputs is prefixed with newline and LINENO

DIR=$1

if [ ! -d "$DIR" ]; then
    echo "ERROR: Expected a directory containing jstacks. $DIR is not a directory."
    exit
fi

FILES=`ls $DIR | sort -n`

SAVEIFS=$IFS
IFS=$'\n'
FILES=($FILES)
IFS=$SAVEIFS

echo $FILES
NB_FILES=${#FILES[@]}
echo $NB_FILES

for (( I=1; I<$NB_FILES; I++ ))
do
    if [ -s $DIR/$(expr $I + 1).txt ]; then
        meld $DIR/$I.txt $DIR/$(expr $I + 1).txt
    fi
done

