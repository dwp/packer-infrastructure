addgroup -g ${gid} ${group} && \
    adduser -S -G ${group} -u ${uid} ${user}

set -eux; \
apk add --no-cache ca-certificates gnupg openssl libcap su-exec dumb-init bind-tools && \
apkArch="$(apk --print-arch)"; \
case "$apkArch" in \
    armhf) ARCH='arm' ;; \
    aarch64) ARCH='arm64' ;; \
    x86_64) ARCH='amd64' ;; \
    x86) ARCH='386' ;; \
    *) echo >&2 "error: unsupported architecture: $apkArch"; exit 1 ;; \
esac && \
found=''; \
for server in \
    hkp://p80.pool.sks-keyservers.net:80 \
    hkp://keyserver.ubuntu.com:80 \
    hkp://pgp.mit.edu:80 \
; do \
    echo "Fetching GPG key $hashicorp_gpgkey from $server"; \
    gpg --keyserver "$server" --recv-keys "$hashicorp_gpgkey" && found=yes && break; \
done; \
test -z "$found" && echo >&2 "error: failed to fetch GPG key $hashicorp_gpgkey" && exit 1; \
mkdir -p /tmp/build && \
cd /tmp/build && \
if [ ${license} = "opensource" ]; \
then \
wget https://releases.hashicorp.com/vault/${version}/vault_${version}_linux_${ARCH}.zip -O vault_${version}_linux_${ARCH}.zip; \
wget https://releases.hashicorp.com/vault/${version}/vault_${version}_SHA256SUMS  -O vault_${version}_SHA256SUMS ;\
wget https://releases.hashicorp.com/vault/${version}/vault_${version}_SHA256SUMS.sig -O vault_${version}_SHA256SUMS.sig; \
gpg --batch --verify vault_${version}_SHA256SUMS.sig vault_${version}_SHA256SUMS ;\
grep vault_${version}_linux_${ARCH}.zip vault_${version}_SHA256SUMS  | sha256sum -c ; \
unzip -d /bin vault_${version}_linux_${ARCH}.zip; \
vault version ;\
elif [ ${license} = "enterprise" ]; \
then \
wget https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/vault/ent/${version}/vault-enterprise_${version}%2Bent_linux_${ARCH}.zip -O vault-enterprise_${version}+ent_linux_${ARCH}.zip  ; \
wget https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/vault/ent/${version}/vault-enterprise_${version}%2Bent_SHA256SUMS -O vault-enterprise_${version}+ent_SHA256SUMS ; \
wget https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/vault/ent/${version}/vault-enterprise_${version}%2Bent_SHA256SUMS.sig -O vault-enterprise_${version}+ent_SHA256SUMS.sig; \
gpg --batch --verify vault-enterprise_${version}+ent_SHA256SUMS.sig vault-enterprise_${version}+ent_SHA256SUMS ; \
grep vault-enterprise_${version}+ent_linux_${ARCH}.zip vault-enterprise_${version}+ent_SHA256SUMS | sha256sum -c ; \
unzip -d /bin vault-enterprise_${version}+ent_linux_${ARCH}.zip ; \
vault version ;\
fi && \
cd /tmp && \
rm -rf /tmp/build && \
gpgconf --kill dirmngr && \
gpgconf --kill gpg-agent && \
apk del gnupg openssl && \
rm -rf /root/.gnupg

mkdir -p /vault/logs && \
mkdir -p /vault/file && \
mkdir -p /vault/config && \
chown -R ${user}:${group} /vault
