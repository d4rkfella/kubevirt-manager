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
    luarocks install lua-resty-string && \
    luarocks install lua-resty-openidc && \
    luarocks install lua-resty-redis-connector && \
    luarocks list && \
    curl -fsSL -o /usr/bin/kubectl https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && \
    chmod +x /usr/bin/kubectl

FROM cgr.dev/chainguard/wolfi-base:latest@sha256:7afaeb1ffbc9c33c21b9ddbd96a80140df1a5fa95aed6411b210bcb404e75c11
ARG VERSION=1.5.0

ENV LUA_PATH=/usr/local/openresty/site/lualib/?.ljbc;/usr/local/openresty/site/lualib/?/init.ljbc;/usr/local/openresty/lualib/?.ljbc;/usr/local/openresty/lualib/?/init.ljbc;/usr/local/openresty/site/lualib/?.lua;/usr/local/openresty/site/lualib/?/init.lua;/usr/local/openresty/lualib/?.lua;/usr/local/openresty/lualib/?/init.lua;./?.lua;/usr/local/openresty/luajit/share/luajit-2.1.0-beta3/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/openresty/luajit/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?/init.lua
ENV LUA_CPATH=/usr/local/openresty/site/lualib/?.so;/usr/local/openresty/lualib/?.so;./?.so;/usr/local/lib/lua/5.1/?.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so

RUN apk add --no-cache \
        openresty \
        libfontconfig1 && \
    mkdir -p /etc/nginx/location.d/ && \
    rm /etc/passwd /etc/group /etc/nginx/nginx.conf && \
    echo 'nginx:x:65532:65532::/nonexistent:/sbin/nologin' > /etc/passwd \ && \
    echo 'nginx:x:65532:' > /etc/group && \
    mkdir /docker-entrypoint.d && \
    chmod 755 /docker-entrypoint.d

COPY --chmod=755 docker-entrypoint.sh /
COPY --chmod=755 15-local-resolvers.envsh 30-tune-worker-processes.sh 91-startkubectl.sh /docker-entrypoint.d/
COPY --from=build --chmod=755 /usr/bin/kubectl /usr/bin/kubectl
COPY --chmod=755 nginx.conf /etc/nginx/nginx.conf
COPY --chmod=755 default.conf /etc/nginx/conf.d/default.conf
COPY --from=kubevirtmanager/kubevirt-manager:1.5.0 --chmod=755 /usr/share/nginx/html /usr/local/openresty/nginx/html
COPY --from=build --chmod=755 /usr/local/lib/luarocks/rocks-5.4 /usr/local/openresty/lualib/resty

USER nginx:nginx

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["openresty", "-g", "daemon off;"]
