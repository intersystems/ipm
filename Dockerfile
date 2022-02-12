ARG BASE=containers.intersystems.com/intersystems/irishealth-community:2022.1.0.114.0
FROM ${BASE}

ARG REGISTRY=https://pm.community.intersystems.com

RUN --mount=type=bind,src=.,dst=/home/irisowner/ipm/ \
  iris start iris && \
  iris session iris -U%SYS "##class(%SYSTEM.OBJ).Load(\"/home/irisowner/ipm/Installer.cls\",\"ck\")" && \
  iris session iris -U%SYS "##class(IPM.Installer).setup(\"/home/irisowner/ipm/\",3)" && \
  iris stop iris quietly


# USER root

# COPY irissession.sh /

# WORKDIR /opt/zpm

# RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} .

# USER ${ISC_PACKAGE_MGRUSER}

# COPY ./Installer.cls ./
# COPY ./ ./


# SHELL [ "/irissession.sh" ]

# RUN \
# Do $system.OBJ.Load("/opt/zpm/Installer.cls","ck") \
# Set ^|"%SYS"|SYS("Security", "CSP", "AllowPercent") = 1 \
# Set v = "/opt/zpm/" \
# Set sc = ##class(%ZPM.Installer).setup(.v, 3) \
# Set ^|"USER"|UnitTestRoot="/opt/zpm/tests/"
