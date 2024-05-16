#!/bin/bash

if [ -z $1 ]; then
    echo "Enter filename of a previous IPM release asset to install: "
    read ASSET_NAME
else
    ASSET_NAME=$1
fi

if [ "$ASSET_NAME" = "local" ]; then
    ASSET_URL="http://registry:52773/registry/packages/zpm/latest/installer"
else
    ASSET_URL=`wget -qO- https://api.github.com/repos/intersystems/ipm/releases | jq -r ".[].assets[] | select(.name == \"${ASSET_NAME}\") | .browser_download_url"`
    if [ "$ASSET_URL" = "" ]; then
        echo "Asset ${ASSET_NAME} not found."
        exit
    fi
fi
wget $ASSET_URL -O /home/irisowner/zpm.xml
/bin/echo "
set sc = ##class(%SYSTEM.OBJ).Load(\"/home/irisowner/zpm.xml\", \"ck\")
zpm \"list\":1
zpm \"repo -r -name registry -url http://registry:52773/registry/ -username admin -password SYS\":1
halt
" | iris session iris -UUSER