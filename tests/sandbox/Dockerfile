ARG BASE=containers.intersystems.com/intersystems/irishealth-community:2024.1
FROM ${BASE}

USER root

RUN apt-get update \
 && apt-get install -y jq \
 && apt-get install -y git

USER irisowner

RUN --mount=type=bind,src=.,dst=/home/irisowner/sandbox/ \
  iris start iris && \
  sh /home/irisowner/sandbox/install-artifact.sh zpm-0.7.1.xml \
  iris stop iris quietly