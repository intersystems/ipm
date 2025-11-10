ARG BASE=containers.intersystems.com/intersystems/irishealth-community:2025.1
FROM ${BASE}

ARG REGISTRY=https://pm.community.intersystems.com

RUN --mount=type=bind,src=.,dst=/home/irisowner/zpm/ \
  iris start iris && \
	iris session IRIS < /home/irisowner/zpm/iris.script && \
  iris stop iris quietly