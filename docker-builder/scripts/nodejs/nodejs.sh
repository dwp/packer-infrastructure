apk -Uuv add groff less python py-pip  \
              && apk add --update apache2-ssl \
              && pip install awscli \
        && apk add --no-cache tini \
              && cp /sbin/tini /usr/local/bin/tini \
              && addgroup -g ${GID} -S ${GROUP} \
              && adduser -u ${UID} -S -G ${USER} ${GROUP} \
              && mkdir -p ${APPHOME} \
              /opt/${USER} \
              /var/log/${APP} \
              && tar -xvf /tmp/app.tar -C ${APPHOME} \
              && cd ${APPHOME} \
              && /usr/local/bin/npm install \
              && rm -rf /tmp/app.tar \
              && chown -R ${USER}:${GROUP} ${APPHOME} \
              ${APPHOME} \
              /opt/${USER} \
              /var/log/${APP}
