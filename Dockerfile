FROM cgr.dev/chainguard/wolfi-base:latest@sha256:7afaeb1ffbc9c33c21b9ddbd96a80140df1a5fa95aed6411b210bcb404e75c11 AS build

WORKDIR /tmp

RUN apk add --no-cache \
        build-base \
        curl && \
    curl -fsSLO http://www.lua.org/ftp/lua-5.4.7.tar.gz && \
    tar zxf lua-5.4.7.tar.gz && \
    cd lua-5.4.7 && \
    make linux test && \
    make install && \
    cd .. && \
    curl -fsSLO https://luarocks.github.io/luarocks/releases/luarocks-3.11.1.tar.gz && \
    tar zxf luarocks-3.11.1.tar.gz && \
    cd luarocks-3.11.1 && \
    ./configure --with-lua-include=/usr/local/include && \
    make && \
    make install && \
    luarocks install lua-resty-openidc && \
    luarocks install lua-resty-redis-connector && \
    curl -fsSL -o /usr/bin/kubectl https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && \
    chmod +x /usr/bin/kubectl && \
    curl -fsSL -o /usr/bin/catatonit https://github.com/openSUSE/catatonit/releases/download/v0.2.1/catatonit.x86_64 && \
    chmod +x /usr/bin/catatonit

FROM cgr.dev/chainguard/wolfi-base:latest@sha256:7afaeb1ffbc9c33c21b9ddbd96a80140df1a5fa95aed6411b210bcb404e75c11
ARG VERSION=1.5.0

RUN apk add --no-cache \
        openresty && \
    mkdir -p /etc/nginx/location.d/ && \
    rm /etc/passwd /etc/group /etc/nginx/nginx.conf && \
    echo 'nginx:x:65532:65532::/nonexistent:/sbin/nologin' > /etc/passwd \ && \
    echo 'nginx:x:65532:' > /etc/group && \
    mkdir /docker-entrypoint.d && \
    chmod 755 /docker-entrypoint.d

COPY --chmod=755 docker-entrypoint.sh /
COPY --chmod=755 10-local-resolvers.envsh 20-envsubst-on-templates.sh 30-tune-worker-processes.sh 40-startkubectl.sh /docker-entrypoint.d
COPY --from=build --chmod=755 /usr/bin/catatonit /usr/bin/kubectl /usr/bin/
COPY --chmod=755 nginx.conf /etc/nginx/nginx.conf
COPY --chmod=755 default.conf /etc/nginx/conf.d/default.conf
COPY --from=kubevirtmanager/kubevirt-manager:1.5.0 --chmod=755 /usr/share/nginx/html /usr/local/openresty/nginx/html
COPY --from=build --chmod=755 /usr/local/share/lua/5.4/resty /usr/local/share/lua/5.4/resty
COPY --from=build --chmod=755 /usr/local/share/lua/5.4/ffi-zlib.lua /usr/local/share/lua/5.4/ffi-zlib.lua

USER nginx:nginx

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["openresty", "-g", "daemon off;"]
