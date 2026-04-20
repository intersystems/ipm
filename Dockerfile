ARG BASE=containers.intersystems.com/intersystems/iris-community:2025.1

FROM ${BASE}

ARG REGISTRY=https://pm.community.intersystems.com

# --- Create dirs and place tools (use --chown to avoid extra chown layers) ---
COPY --chown=irisowner:irisowner iriscli /home/irisowner/bin/iriscli
COPY --chown=irisowner:irisowner ipm    /home/irisowner/bin/ipm
RUN chmod +x /home/irisowner/bin/iriscli /home/irisowner/bin/ipm

RUN --mount=type=bind,src=.,dst=/home/irisowner/zpm/ \
    iris start iris && \
    iris session IRIS < /home/irisowner/zpm/iris.script && \
    iris stop iris quietly