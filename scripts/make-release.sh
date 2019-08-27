#!/bin/bash

RELEASE_FILE=`pwd`/$1
VERSION=$2

iris start $ISC_PACKAGE_INSTANCENAME EmergencyId=sys,sys 
/bin/echo -e "sys\nsys\n" \
        " Do ##class(%ZPM.Installer).Release(\"${RELEASE_FILE}\", \"${VERSION}\")\n" \
        " halt" \
| iris session $ISC_PACKAGE_INSTANCENAME

/bin/echo -e "sys\nsys\n" \
| iris stop $ISC_PACKAGE_INSTANCENAME quietly
