apk update && apk upgrade \
        && apk -Uuv add less python py-pip  \
        && apk add --update apache2-ssl \
        && pip install --upgrade awscli pip \
        && apk add --no-cache tini \
        && cp /sbin/tini /usr/local/bin/tini \
        && addgroup -g ${GID} -S ${GROUP} \
        && adduser -u ${UID} -S -G ${USER} ${GROUP} \
        && apk add --no-cache curl \
        && apk add --no-cache ca-certificates gnupg openssl libcap su-exec dumb-init  \
        && apk del python2-dev && \
        apkArch="$(apk --print-arch)"; \
        case "$apkArch" in \
            armhf) ARCH='arm' ;; \
            aarch64) ARCH='arm64' ;; \
            x86_64) ARCH='amd64' ;; \
            x86) ARCH='386' ;; \
            *) echo >&2 "error: unsupported architecture: $apkArch"; exit 1 ;; \
        esac && \
        VAULT_GPGKEY=91A6E7F85D05C65630BEF18951852D87348FFC4C; \
        found=''; \
        for server in \
            hkp://p80.pool.sks-keyservers.net:80 \
            hkp://keyserver.ubuntu.com:80 \
            hkp://pgp.mit.edu:80 \
        ; do \
            echo "Fetching GPG key $VAULT_GPGKEY from $server"; \
            gpg --keyserver "$server" --recv-keys "$VAULT_GPGKEY" && found=yes && break; \
        done; \
        test -z "$found" && echo >&2 "error: failed to fetch GPG key $VAULT_GPGKEY" && exit 1; \
        mkdir -p /tmp/build && \
        cd /tmp/build && \
        if [ ${VAULT_LICENSE} = "opensource" ]; \
        then \
        wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${ARCH}.zip && \
        wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS && \
        wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS.sig && \
        gpg --batch --verify vault_${VAULT_VERSION}_SHA256SUMS.sig vault_${VAULT_VERSION}_SHA256SUMS && \
        grep vault_${VAULT_VERSION}_linux_${ARCH}.zip vault_${VAULT_VERSION}_SHA256SUMS | sha256sum -c && \
        unzip -d /bin vault_${VAULT_VERSION}_linux_${ARCH}.zip && \
        vault version ; \
        elif [ ${VAULT_LICENSE} = "enterprise" ]; \
        then \
        wget https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/vault/ent/${VAULT_VERSION}/vault-enterprise_${VAULT_VERSION}%2Bent_linux_${ARCH}.zip -O vault-enterprise_${VAULT_VERSION}+ent_linux_${ARCH}.zip  ; \
        wget https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/vault/ent/${VAULT_VERSION}/vault-enterprise_${VAULT_VERSION}%2Bent_SHA256SUMS -O vault-enterprise_${VAULT_VERSION}+ent_SHA256SUMS ; \
        wget https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/vault/ent/${VAULT_VERSION}/vault-enterprise_${VAULT_VERSION}%2Bent_SHA256SUMS.sig -O vault-enterprise_${VAULT_VERSION}+ent_SHA256SUMS.sig; \
        gpg --batch --verify vault-enterprise_${VAULT_VERSION}+ent_SHA256SUMS.sig vault-enterprise_${VAULT_VERSION}+ent_SHA256SUMS ; \
        grep vault-enterprise_${VAULT_VERSION}+ent_linux_${ARCH}.zip vault-enterprise_${VAULT_VERSION}+ent_SHA256SUMS | sha256sum -c ; \
        unzip -d /bin vault-enterprise_${VAULT_VERSION}+ent_linux_${ARCH}.zip ; \
        vault version ;\
        fi && \
        cd /tmp && \
        rm -rf /tmp/build && \
        gpgconf --kill dirmngr && \
        gpgconf --kill gpg-agent && \
        apk del gnupg openssl && \
        rm -rf /root/.gnupg && \
        setcap cap_ipc_lock=+ep $(readlink -f $(which vault)) \
        && apk add --no-cache ca-certificates gnupg openssl libcap su-exec dumb-init && \
        apkArch="$(apk --print-arch)"; \
        CONSUL_TEMPLATE_GPGKEY=91A6E7F85D05C65630BEF18951852D87348FFC4C; \
        found=''; \
        for server in \
            hkp://p80.pool.sks-keyservers.net:80 \
            hkp://keyserver.ubuntu.com:80 \
            hkp://pgp.mit.edu:80 \
        ; do \
            echo "Fetching GPG key $CONSUL_TEMPLATE_GPGKEY from $server"; \
            gpg --keyserver "$server" --recv-keys "$CONSUL_TEMPLATE_GPGKEY" && found=yes && break; \
        done; \
        test -z "$found" && echo >&2 "error: failed to fetch GPG key $CONSUL_TEMPLATE_GPGKEY" && exit 1; \
        mkdir -p /tmp/build && \
        cd /tmp/build && \
        wget https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_${ARCH}.zip && \
        wget https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_SHA256SUMS && \
        wget https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_SHA256SUMS.sig && \
        gpg --batch --verify consul-template_${CONSUL_TEMPLATE_VERSION}_SHA256SUMS.sig consul-template_${CONSUL_TEMPLATE_VERSION}_SHA256SUMS && \
        grep consul-template_${CONSUL_TEMPLATE_VERSION}_linux_${ARCH}.zip consul-template_${CONSUL_TEMPLATE_VERSION}_SHA256SUMS | sha256sum -c && \
        unzip -d /bin consul-template_${CONSUL_TEMPLATE_VERSION}_linux_${ARCH}.zip && \
        consul-template -version && \
        cd /tmp && \
        rm -rf /tmp/build && \
        gpgconf --kill dirmngr && \
        gpgconf --kill gpg-agent && \
        apk del gnupg openssl && \
        rm -rf /root/.gnupg
