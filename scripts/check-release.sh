#!/bin/bash

RELEASE_FILE=`pwd`/$1

iris start $ISC_PACKAGE_INSTANCENAME EmergencyId=sys,sys 
/bin/echo -e "sys\nsys\n" \
        "Do \$system.OBJ.Load(\"${RELEASE_FILE}\", \"ck\")\n" \
        "zpm \"repo -list\"\n" \
        "zpm \"list\"\n" \
        "zn \"user\"\n" \
        "zpm \"install AnalyzeThis\"\n" \
        "zpm \"install ThirdPartyChartPortlets\"\n" \
        "zpm \"install DeepSeeButtons\"\n" \
        "halt" \
| iris session $ISC_PACKAGE_INSTANCENAME

/bin/echo -e "sys\nsys\n" \
| iris stop $ISC_PACKAGE_INSTANCENAME quietly

        # "zpm \"list\"\n" \
        # "zpm \"install zpm\"\n" \
        # "zpm \"list\"\n" \
