ARG BASE=containers.intersystems.com/intersystems/iris-community:2024.1
FROM ${BASE}

USER root

RUN apt-get update \
 && apt-get install -y jq

USER irisowner