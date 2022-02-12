ARG BASE=containers.intersystems.com/intersystems/irishealth-community:2022.1.0.114.0
FROM ${BASE}

ARG REGISTRY=https://pm.community.intersystems.com

RUN --mount=type=bind,src=.,dst=/home/irisowner/ipm/ \
  iris start iris && \
  iris session iris -U%SYS "##class(%SYSTEM.OBJ).Load(\"/home/irisowner/ipm/Installer.cls\",\"ck\")" && \
  iris session iris -U%SYS "##class(IPM.Installer).setup(\"/home/irisowner/ipm/\",3)" && \
  iris stop iris quietly
