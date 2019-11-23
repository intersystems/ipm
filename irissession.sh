#!/bin/bash

iris start $ISC_PACKAGE_INSTANCENAME quietly
 
cat << EOF | iris session $ISC_PACKAGE_INSTANCENAME -U %SYS
do ##class(%SYSTEM.Process).CurrentDirectory("$PWD")
$@
if '\$Get(sc) do ##class(%SYSTEM.Process).Terminate(, 1)
zn "%SYS"
do ##class(SYS.Container).QuiesceForBundling()
Do ##class(Security.Users).UnExpireUserPasswords("*")
halt
EOF

exit=$?

iris stop $ISC_PACKAGE_INSTANCENAME quietly

exit $exit