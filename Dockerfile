ARG BASE=containers.intersystems.com/intersystems/irishealth-community:2022.1.0.114.0
FROM ${BASE}

ARG REGISTRY=https://pm.community.intersystems.com

RUN --mount=type=bind,src=.,dst=/home/irisowner/zpm/ \
  iris start iris && \
  iris session iris "##class(%SYSTEM.OBJ).Load(\"/home/irisowner/zpm/Installer.cls\",\"ck\")" && \
  iris session iris "##class(%ZPM.Installer).setup(\"/home/irisowner/zpm/\",3)" && \
  iris stop iris quietly