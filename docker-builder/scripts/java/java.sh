mkdir -p ${APPHOME} \
        /opt/${USER} \
        /tmp/${APP} \
        && tar -xvf /tmp/app.tar -C /tmp/${APP} \
        && rm -rf /tmp/app.tar \
        && mv /tmp/${APP}/${APP}*.jar ${APPHOME}/${APP}.jar \
        && mv /tmp/${APP}/properties ${APPHOME} \
        && rm -rf /tmp/${APP} \
        && chown -R ${USER}:${GROUP} \
        ${APPHOME} \
        /opt/${USER}
