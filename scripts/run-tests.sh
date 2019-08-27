#!/bin/bash

RELEASE_FILE=`pwd`/$1

iris start $ISC_PACKAGE_INSTANCENAME EmergencyId=sys,sys 
/bin/echo -e "sys\nsys\n" \
        " zpm \"module-action zpm test -v\"\n" \
        " halt" \
| iris session $ISC_PACKAGE_INSTANCENAME | tee /tmp/tests.log
        # " zpm \"module-action zpm verify -v\"\n" \

/bin/echo -e "sys\nsys\n" \
| iris stop $ISC_PACKAGE_INSTANCENAME quietly

if ! grep -iq "Test SUCCESS" /tmp/tests.log 
then
  exit 1
fi
# if ! grep -iq "Verify SUCCESS" /tmp/tests.log 
# then
#   exit 1
# fi
