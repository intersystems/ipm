ARG BASE=irepo.intersystems.com/intersystems/iris-community:latest-cd

FROM ${BASE}

ARG REGISTRY=https://pm.community.intersystems.com

RUN --mount=type=bind,src=.,dst=/home/irisowner/zpm/ \
  iris start iris && \
	iris session IRIS < /home/irisowner/zpm/iris.script && \
  iris stop iris quietly