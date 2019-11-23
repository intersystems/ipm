FROM store/intersystems/iris-community:2019.4.0.379.0

USER root

COPY irissession.sh /

WORKDIR /opt/zpm

RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} .

USER ${ISC_PACKAGE_MGRUSER}

COPY ./Installer.cls ./
COPY ./ ./

ARG REGISTRY=https://pm.community.intersystems.com

SHELL [ "/irissession.sh" ]

RUN \
Do $system.OBJ.Load("/opt/zpm/Installer.cls","ck") \
Set ^|"%SYS"|SYS("Security", "CSP", "AllowPercent") = 1 \
Set v = "/opt/zpm/" \
Set sc = ##class(%ZPM.Installer).setup(.v, 3) \
Set ^|"USER"|UnitTestRoot="/opt/zpm/tests/"