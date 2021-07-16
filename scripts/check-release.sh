#!/bin/bash

RELEASE_FILE=`pwd`/$1

iris start $ISC_PACKAGE_INSTANCENAME 
/bin/echo -e "" \
        "Do \$system.OBJ.Load(\"${RELEASE_FILE}\", \"ck\")\n" \
        "zpm \"repo -list\"\n" \
        "zpm \"list\"\n" \
        "zn \"user\"\n" \
        "zpm \"install zapm-editor\"\n" \
        "halt" \
| iris session $ISC_PACKAGE_INSTANCENAME
        # "zpm \"install analyzethis\"\n" \

iris stop $ISC_PACKAGE_INSTANCENAME quietly
