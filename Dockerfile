ARG BASE=containers.intersystems.com/intersystems/iris-community:2026.1

FROM ${BASE} AS ipm

ARG REGISTRY=https://pm.community.intersystems.com

ARG TARGETARCH

# The notary CLI verifies packages from ORAS repos configured with -trust-server. The tests also sign with it.
# v0.6.1 is its last release with prebuilt binaries. Its only Linux build is for amd64.
USER root
RUN if [ "${TARGETARCH:-amd64}" = "amd64" ]; then \
        python3 -c "import sys, urllib.request; urllib.request.urlretrieve(sys.argv[1], '/usr/local/bin/notary')" \
            https://github.com/notaryproject/notary/releases/download/v0.6.1/notary-Linux-amd64 && \
        echo "73353b2b4b85604c738a6800465133cb3a828dff0aa26f3c0926dd9a73e19879  /usr/local/bin/notary" | sha256sum -c - && \
        chmod 755 /usr/local/bin/notary; \
    fi
USER ${ISC_PACKAGE_MGRUSER}

RUN --mount=type=bind,src=.,dst=/home/irisowner/zpm/ \
    iris start iris && \
    iris session IRIS < /home/irisowner/zpm/iris.script && \
    iris stop iris quietly

FROM ipm AS content-trust-test
USER root
COPY --chmod=644 tests/notary/certs/root-ca.crt /usr/local/share/ca-certificates/ipm-test-notary-ca.crt
RUN update-ca-certificates
USER ${ISC_PACKAGE_MGRUSER}

FROM ipm AS release
