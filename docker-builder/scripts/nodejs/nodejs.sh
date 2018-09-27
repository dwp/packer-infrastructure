# Install Node
addgroup -g 1000 node \
    && adduser -u 1000 -G node -s /bin/sh -D node \
    && apk add --no-cache \
        libstdc++ \
    && apk add --no-cache --virtual .build-deps \
        binutils-gold \
        curl \
        g++ \
        gcc \
        gnupg \
        libgcc \
        linux-headers \
        make \
        python \
        && curl -fsSLO --compressed "https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION.tar.xz" \
          && tar -xf "node-$NODE_VERSION.tar.xz" \
          && cd "node-$NODE_VERSION" \
          && ./configure \
          && make -j$(getconf _NPROCESSORS_ONLN) \
          && make install \
          && apk del .build-deps \
          && cd .. \
          && rm -Rf "node-$NODE_VERSION" \
          && rm "node-$NODE_VERSION.tar.xz" \
    && apk -Uuv add groff less python py-pip  \
                  && apk add --update apache2-ssl \
                  && pip install awscli \
          	&& apk add --no-cache tini \
                  && cp /sbin/tini /usr/local/bin/tini \
                  && echo -e "export APP=${APP}\n$(cat /etc/profile)" > /etc/profile \
                  && echo -e "export VERSION=${VERSION}\n$(cat /etc/profile)" > /etc/profile \
                  && addgroup -g ${GID} -S ${GROUP} \
                  && adduser -u ${UID} -S -G ${USER} ${GROUP} \
                  && mkdir -p ${APPHOME} \
                  /opt/${USER} \
                  /var/log/${APP} \
                  && tar -xvf /tmp/app.tar -C ${APPHOME} \
                  && rm -rf /tmp/app.tar \
                  && chown -R ${USER}:${GROUP} \
                  ${APPHOME} \
                  /opt/${USER} \
                  /var/log/${APP}
