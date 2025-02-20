FROM ghcr.io/d4rkfella/nginx:1.27.4@sha256:ddc68b460bba378028a2d7d91bb1c92ad8db20f062def3af2e764099df04dacf

ARG VERSION=1.5.0

FROM kubevirtmanager/kubevirt-manager:${VERSION} as kubevirtmanager

LABEL description="Kubevirt Manager ${VERSION}"

RUN mkdir -p /etc/nginx/location.d/ && \
    curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && mv ./kubectl /usr/local/bin && \
    rm /etc/passwd /etc/group /etc/nginx/nginx.conf && \
    echo 'nginx:x:65532:65532::/nonexistent:/sbin/nologin' > /etc/passwd \ && \
    echo 'nginx:x:65532:' > /etc/group

COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=kubevirtmanager /docker-entrypoint.d /docker-entrypoint.d
COPY --from=kubevirtmanager /etc/nginx/conf.d /etc/nginx/conf.d
COPY --from=kubevirtmanager /usr/share/nginx/html /usr/share/nginx/html
