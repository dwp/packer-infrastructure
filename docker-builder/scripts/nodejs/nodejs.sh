mkdir -p ${APPHOME} \
        /opt/${USER} \
        /tmp/${APP} \
        && tar -xvf /tmp/app.tar  --strip-components=1 -C /tmp/${APP} \
        && mv /tmp/${APP}/package.json /tmp/${APP}/app  /tmp/${APP}/node_modules /tmp/${APP}/index.js /tmp/${APP}/properties ${APPHOME} \
        && cd ${APPHOME} \
        && /usr/local/bin/npm install \
        && rm -rf /tmp/app.tar \
        && rm -fr /tmp/${APP} \
        && chown -R ${USER}:${GROUP} ${APPHOME} \
        ${APPHOME} \
        /opt/${USER}
