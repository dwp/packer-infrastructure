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
wget https://releases.hashicorp.com/consul/${version}/consul_${version}_linux_${ARCH}.zip -O consul_${version}_linux_${ARCH}.zip ; \
wget https://releases.hashicorp.com/consul/${version}/consul_${version}_SHA256SUMS  -O consul_${version}_SHA256SUMS  ; \
wget https://releases.hashicorp.com/consul/${version}/consul_${version}_SHA256SUMS.sig -O consul_${version}_SHA256SUMS.sig ; \
gpg --batch --verify consul_${version}_SHA256SUMS.sig consul_${version}_SHA256SUMS ; \
grep consul_${version}_linux_${ARCH}.zip consul_${version}_SHA256SUMS  | sha256sum -c ; \
unzip -d /bin consul_${version}_linux_${ARCH}.zip ; \
consul version ;\
elif [ ${license} = "enterprise" ]; \
then \
wget https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/consul/ent/${version}/consul-enterprise_${version}%2Bent_linux_${ARCH}.zip -O consul-enterprise_${version}+ent_linux_${ARCH}.zip ; \
wget https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/consul/ent/${version}/consul-enterprise_${version}%2Bent_SHA256SUMS -O consul-enterprise_${version}+ent_SHA256SUMS ; \
wget https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/consul/ent/${version}/consul-enterprise_${version}%2Bent_SHA256SUMS.sig -O consul-enterprise_${version}+ent_SHA256SUMS.sig ; \
gpg --batch --verify consul-enterprise_${version}+ent_SHA256SUMS.sig consul-enterprise_${version}+ent_SHA256SUMS ; \
grep consul-enterprise_${version}+ent_linux_${ARCH}.zip consul-enterprise_${version}+ent_SHA256SUMS | sha256sum -c ; \
unzip -d /bin consul-enterprise_${version}+ent_linux_${ARCH}.zip ; \
consul version ;\
fi && \
cd /tmp && \
rm -rf /tmp/build && \
gpgconf --kill dirmngr && \
gpgconf --kill gpg-agent && \
apk del gnupg openssl && \
rm -rf /root/.gnupg

mkdir -p /consul/data && \
mkdir -p /consul/config && \
chown -R ${user}:${group} /consul
