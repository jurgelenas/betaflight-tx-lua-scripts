#!/usr/bin/env bash

# The COMPILE manifest is committed under src/, not generated here -- edgetx-cli
# installs straight from src/ and never runs this script. Fail early if a file
# was added or removed without re-running 'make manifest'.
if ! bin/manifest.sh --check; then
    exit 1
fi

if [ -d obj ]; then
    rm -fR obj/*
else
    mkdir obj
fi

cp -fR src/* obj

MANIFEST=(`find obj/ -name *.lua -type f`);
LAST_FAILURE=0

if [ ${#MANIFEST[@]} -eq 0 ]; then
    echo -e "\e[1m\e[39m[\e[31mTEST FAILED\e[39m]\e[21m No scripts could be found!."
    exit 1
fi

for f in ${MANIFEST[@]};
do
    SRC_NAME=$f
    echo -e "Testing file \e[1m${SRC_NAME}\e[21m..."
    luac -p ${SRC_NAME}
    _fail=$?
    if [[ $_fail -ne 0 ]]; then
        LAST_FAILURE=$_fail
        echo -e "\e[1m\e[39m[\e[31mBUILD FAILED\e[39m]\e[21m Error in file ${SRC_NAME}\e[1m"
    fi
done

if [[ $LAST_FAILURE -eq 0 ]]; then
    echo -e "\e[1m\e[39m[\e[32mTEST SUCCESSFUL\e[39m]\e[21m"
fi
exit $LAST_FAILURE
