ARG BASE=containers.intersystems.com/intersystems/iris-community:2026.1

FROM ${BASE}

# Build the package registry: create the REGISTRY namespace, install IPM from
# this repo's source, then install the zpm-registry module. The community image
# ships without IPM and does not auto-create namespaces, so we do both here.
# Build context is the repo root so preload/ and src/ are available.
RUN --mount=type=bind,src=.,dst=/home/irisowner/zpm/ \
    iris start iris && \
    iris session iris -U%SYS < /home/irisowner/zpm/tests/registry/setup-registry.script && \
    iris stop iris quietly
