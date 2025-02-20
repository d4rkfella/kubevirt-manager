FROM ghcr.io/d4rkfella/nginx:latest@sha256:800acd1dc436a007212fdd1ece55813b996a73b8b9b7e4c9c04b7b4ffca3c592

ARG VERSION=1.5.0

LABEL description="Kubevirt Manager ${VERSION}"

RUN mkdir -p /etc/nginx/location.d/
RUN curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && mv ./kubectl /usr/local/bin
COPY --from=kubevirtmanager/kubevirt-manager:1.5.0 /docker-entrypoint.d /docker-entrypoint.d
COPY --from=kubevirtmanager/kubevirt-manager:1.5.0 /etc/nginx/conf.d /etc/nginx/conf.d
COPY --from=kubevirtmanager/kubevirt-manager:1.5.0 /usr/share/nginx/html /usr/share/nginx/html
