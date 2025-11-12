ARG BASE=containers.intersystems.com/intersystems/iris-community:2025.1
FROM ${BASE}
ARG IPM_VERSION=zpm-0.7.2.xml

USER root

RUN apt-get update \
    && apt-get install -y jq \
    && apt-get install -y git

USER irisowner

RUN --mount=type=bind,src=.,dst=/home/irisowner/sandbox/ \
    iris start iris && \
    sh /home/irisowner/sandbox/install-artifact.sh $IPM_VERSION \
    iris stop iris quietly