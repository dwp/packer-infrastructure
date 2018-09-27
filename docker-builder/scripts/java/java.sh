apk -Uuv add groff less python py-pip  \
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
        && mv ${APPHOME}/${APP}*.jar ${APPHOME}/${APP}.jar \
        && chown -R ${USER}:${GROUP} \
        ${APPHOME} \
        /opt/${USER} \
        /var/log/${APP}
