FROM intersystems/iris:2019.3.0.302.0

WORKDIR /opt/zpm

COPY ./Installer.cls ./
COPY ./ ./

ARG REGISTRY=https://pm.community.intersystems.com

RUN iris start $ISC_PACKAGE_INSTANCENAME quietly EmergencyID=admin,sys && \
    /bin/echo -e "admin\nsys\n" \
            " Do ##class(Security.Users).UnExpireUserPasswords(\"*\")\n" \
            " Do ##class(Security.Users).AddRoles(\"admin\", \"%ALL\")\n" \
            " Do ##class(Security.System).Get(, .p)\n" \
            " Set p(\"AutheEnabled\") = \$zb(p(\"AutheEnabled\"), 16, 7)\n" \
            " Do ##class(Security.System).Modify(, .p)\n" \
            " Do \$system.OBJ.Load(\"/opt/zpm/Installer.cls\",\"ck\")\n" \
            " Set v = \"/opt/zpm/\"\n" \
            " Set:\"${REGISTRY}\"'=\"\" v(\"REGISTRY\") = \"${REGISTRY}\"\n" \
            " Set sc = ##class(%ZPM.Installer).setup(.v, 3)\n" \
            " Set ^|\"%SYS\"|SYS(\"Security\", \"CSP\", \"AllowPercent\") = 1\n" \
            " If 'sc do \$zu(4, \$JOB, 1)\n" \
            ' Set ^|"USER"|UnitTestRoot="/opt/zpm/tests/"\n' \
            " Halt" \
    | iris session $ISC_PACKAGE_INSTANCENAME -U%SYS && \
    /bin/echo -e "admin\nsys\n" \
    | iris stop $ISC_PACKAGE_INSTANCENAME quietly

CMD [ "-l", "/usr/irissys/mgr/messages.log" ]
