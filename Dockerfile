FROM cgr.dev/chainguard/wolfi-base:latest@sha256:7afaeb1ffbc9c33c21b9ddbd96a80140df1a5fa95aed6411b210bcb404e75c11
ARG VERSION=1.5.0

ENV LUA_PATH=/usr/local/openresty/site/lualib/?.ljbc;/usr/local/openresty/site/lualib/?/init.ljbc;/usr/local/openresty/lualib/?.ljbc;/usr/local/openresty/lualib/?/init.ljbc;/usr/local/openresty/site/lualib/?.lua;/usr/local/openresty/site/lualib/?/init.lua;/usr/local/openresty/lualib/?.lua;/usr/local/openresty/lualib/?/init.lua;./?.lua;/usr/local/openresty/luajit/share/luajit-2.1.0-beta3/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/openresty/luajit/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?/init.lua
ENV LUA_CPATH=/usr/local/openresty/site/lualib/?.so;/usr/local/openresty/lualib/?.so;./?.so;/usr/local/lib/lua/5.1/?.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so
ENV SHELL=/bin/bash

WORKDIR /tmp

RUN apk add --no-cache \
        bash \
        libfontconfig1 \
        perl \
        libgcc \
        geoip \
        libbrotlidec1 \
        pcre && \
    apk add --no-cache --virtual .build-deps \
        build-base \
        perl-dev \
        git \
        curl \
        openssl-dev \
        pcre-dev \
        zlib-dev \
        readline-dev \
        geoip-dev \
        gd-dev \
        coreutils \
        linux-headers \
        libxml2-dev \
        libxslt-dev && \
    git clone https://luajit.org/git/luajit.git && \
    cd luajit && \
    make && \
    make install && \
    cd .. && \
    curl -fsSLO https://openresty.org/download/openresty-1.27.1.1.tar.gz && \
    tar zxf openresty-1.27.1.1.tar.gz && \
    cd openresty-1.27.1.1 && \
    ./configure \
        --with-pcre \
        --with-cc-opt='-DNGX_LUA_ABORT_AT_PANIC -I/usr/include' \
        --with-ld-opt='-L/usr/lib -Wl,-rpath,/usr/lib' \
        --with-compat \
        --conf-path=/etc/nginx/nginx.conf \
        --sbin-path=/usr/sbin/nginx \
        --error-log-path=/var/log/openresty/error.log \
        --http-log-path=/var/log/openresty/access.log \
        --pid-path=/var/log/openresty/nginx.pid \
        --lock-path=/var/log/openresty/nginx.lock \
        --http-client-body-temp-path=/var/run/openresty/nginx-client-body \
        --http-proxy-temp-path=/var/run/openresty/nginx-proxy \
        --http-fastcgi-temp-path=/var/run/openresty/nginx-fastcgi \
        --http-uwsgi-temp-path=/var/run/openresty/nginx-uwsgi \
        --http-scgi-temp-path=/var/run/openresty/nginx-scgi \
        --with-file-aio \
        --with-http_addition_module \
        --with-http_auth_request_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_geoip_module=dynamic \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_image_filter_module=dynamic \
        --with-http_mp4_module \
        --with-http_random_index_module \
        --with-http_realip_module \
        --with-http_secure_link_module \
        --with-http_slice_module \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_v2_module \
        --with-http_v3_module \
        --with-http_xslt_module=dynamic \
        --with-mail \
        --with-mail_ssl_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-threads \
        --with-luajit-xcflags='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT' \
        --with-pcre-jit && \
    make && \
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
    mkdir -p /etc/nginx/location.d/ && \
    rm /etc/passwd /etc/group && \
    echo 'nginx:x:65532:65532::/nonexistent:/sbin/nologin' > /etc/passwd \ && \
    echo 'nginx:x:65532:' > /etc/group && \
    mkdir /docker-entrypoint.d && \
    chmod 755 /docker-entrypoint.d && \
    apk del --purge .build-deps && \
    rm -rf /tmp/*

COPY --chmod=755 docker-entrypoint.sh /
COPY --chmod=755 30-tune-worker-processes.sh 45-create-bundle-ca.sh 91-startkubectl.sh /docker-entrypoint.d/
COPY --chmod=755 nginx.conf /etc/nginx/nginx.conf
COPY --chmod=755 default.conf /etc/nginx/conf.d/default.conf
COPY --from=kubevirtmanager/kubevirt-manager:1.5.0 --chmod=755 /usr/share/nginx/html /usr/local/openresty/nginx/html

WORKDIR /etc/nginx

USER nginx:nginx

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["nginx", "-g", "daemon off;"]
