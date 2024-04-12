#!/bin/bash

RELEASE_FILE=`pwd`/$1
VERSION=$2

rm -rf /opt/out/*

iris start $ISC_PACKAGE_INSTANCENAME
/bin/echo -e \
        " zpm \"package zpm -only -p \"\"/tmp/zpm-${VERSION}\"\" \":1\n" \
        " set sc = ##class(IPM.Installer).MakeFile(\"/tmp/zpm-${VERSION}.tgz\", \"${RELEASE_FILE}\")\n" \
        " halt" \
| iris session $ISC_PACKAGE_INSTANCENAME -U%SYS

iris stop $ISC_PACKAGE_INSTANCENAME quietly
