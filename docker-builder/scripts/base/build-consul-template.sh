#!/bin/sh
#APP=$1
#DESTFILE=$2
#APPTYPE=$3

if [[ -z $APP || -z $DESTFILE || -z $APPTYPE ]]; then
  echo "ERROR: APP, DESTFILE and APPTYPE variables are empty"
  exit 1
fi

if [ ! -d /consul-template ]; then
  mkdir -p /consul-template
fi

CONSUL_CA_TEMPLATE_FILE="/consul-template/ca-configuration.hcl.tmpl"
CONSUL_SERVER_CERT_TEMPLATE_FILE="/consul-template/server-cert-configuration.hcl.tmpl"
CONSUL_CLIENT_CERT_TEMPLATE_FILE="/consul-template/client-cert-configuration.hcl.tmpl"
CONSUL_APP_TEMPLATE_FILE="/consul-template/app-startup.hcl.tmpl"

function  basic_template {
  CONSUL_TEMPLATE_FILE=$1
  CONSUL_PID_FILE=$2
cat << EOF >> $CONSUL_TEMPLATE_FILE
reload_signal = "SIGHUP"
kill_signal = "SIGINT"
max_stale = "10m"
log_level = "CONSUL_TEMPLATE_LOG_LEVEL"
pid_file = "/home/burbank/$CONSUL_PID_FILE"
wait {
  min = "60s"
  max = "180s"
}
EOF
}

function vault_config {
  CONSUL_TEMPLATE_FILE=$1
cat << EOF >> $CONSUL_TEMPLATE_FILE
vault {
  address = "VAULT_ADDR"
  grace = "5m"
  unwrap_token = false
  renew_token = true
  retry {
    enabled = true
    attempts = 0
    backoff = "250ms"
    max_backoff = "1m"
  }
  ssl {
    enabled = true
    verify = true
    ca_cert = "VAULT_CACERT"
  }
}
EOF
}

function ca_template {
  APPTYPE=$1
  CONSUL_TEMPLATE_FILE=$2
  CONSUL_PID_FILE=$3
cat << EOF >> $CONSUL_TEMPLATE_FILE
template {
  contents="{{ with secret \"VAULT_PKI_PATH/cert/ca\" }}{{ .Data.certificate }}{{ end }}"
  destination="/opt/burbank/ca_dir/project_ca.crt"
  error_on_missing_key = true
  perms = 0755
  backup = true
  left_delimiter = "{{"
  right_delimiter = "}}"
  wait {
   min = "2s"
   max = "10s"
  }
}
template {
  contents="{{ with secret \"VAULT_INT_PATH/cert/ca\" }}{{ .Data.certificate }}{{ end }}"
  destination="/opt/burbank/ca_dir/vault_server_int_ca.crt"
  error_on_missing_key = true
  perms = 0755
  backup = true
  left_delimiter = "{{"
  right_delimiter = "}}"
  wait {
   min = "2s"
   max = "10s"
  }
}
template {
  source="/opt/burbank/ca.tmpl"
  destination="/opt/burbank/ca.crt"
  error_on_missing_key = true
  perms = 0755
  backup = true
  left_delimiter = "{{"
  right_delimiter = "}}"
  wait {
   min = "2s"
   max = "10s"
  }
  command_timeout = "60s"
  command = "python /usr/local/bin/process_certificate.py truststore"
}
EOF
}

function server_cert_template {
    APPTYPE=$1
    CONSUL_TEMPLATE_FILE=$2
cat << EOF >> $CONSUL_TEMPLATE_FILE
template {
  source = "/opt/burbank/certs/server-cert.tmpl"
  destination = "/opt/burbank/certs/server-cert-file"
  create_dest_dirs = true
  error_on_missing_key = true
  perms = 0644
  backup = true
  left_delimiter = "{{"
  right_delimiter = "}}"
  wait {
   min = "2s"
   max = "10s"
  }
  command_timeout = "60s"
  command = "python /usr/local/bin/process_certificate.py server_cert"
}
EOF
}

function client_cert_template {
  APPTYPE=$1
  CONSUL_TEMPLATE_FILE=$2
cat << EOF >> $CONSUL_TEMPLATE_FILE
template {
  source = "/opt/burbank/certs/client-cert.tmpl"
  destination = "/opt/burbank/certs/client-cert-file"
  create_dest_dirs = true
  error_on_missing_key = true
  perms = 0644
  backup = true
  left_delimiter = "{{"
  right_delimiter = "}}"
  wait {
   min = "2s"
   max = "10s"
  }
  command_timeout = "60s"
  command = "python /usr/local/bin/process_certificate.py client_cert"
}
EOF
}

function app_startup_template {
  APP=$1
  APPTYPE=$2
  DESTFILE=$3
  CONSUL_TEMPLATE_FILE=$4
if [[ $APPTYPE = "nginx" ]]; then
  ERROR_ON_MISSING_KEY="false"
else
  ERROR_ON_MISSING_KEY="true"
fi
cat << EOF >> $CONSUL_TEMPLATE_FILE
exec {
  splay = "5s"
  env {
    pristine = false
  }
  reload_signal = "SIGHUP"
  kill_signal = "SIGINT"
  kill_timeout = "5s"
EOF
if [[ $APPTYPE = "java" ]]; then
cat << EOF >> $CONSUL_TEMPLATE_FILE
  command = "/usr/bin/java APP_STARTUP_OPTIONS -jar /opt/$APP/$APP.jar server /opt/burbank/$DESTFILE"
EOF
elif [[ $APPTYPE = "nodejs" ]]; then
cat << EOF >> $CONSUL_TEMPLATE_FILE
  command = "/usr/local/bin/pm2-runtime start /opt/burbank/$DESTFILE APP_STARTUP_OPTIONS"
EOF
elif [[ $APPTYPE = "nginx" ]]; then
cat << EOF >> $CONSUL_TEMPLATE_FILE
  command = "/usr/sbin/nginx -c /opt/burbank/$DESTFILE -g 'daemon off;' APP_STARTUP_OPTIONS"
EOF
fi

cat << EOF >> $CONSUL_TEMPLATE_FILE
}
template {
  source="/opt/burbank/app-config.ctmpl"
  destination="/opt/burbank/$DESTFILE"
  create_dest_dirs = true
  error_on_missing_key = $ERROR_ON_MISSING_KEY
  perms = 0644
  backup = true
  left_delimiter = "{{"
  right_delimiter = "}}"
  wait {
   min = "2s"
   max = "10s"
  }
}
EOF
}
# Go to each function and add any specific commands required for each app type. Currently we have only for Java

# Construct CA Template. This will be the first template and it will only have the vault configuration. One place is enough
basic_template $CONSUL_CA_TEMPLATE_FILE "consul_template_ca_pid_file"
vault_config $CONSUL_CA_TEMPLATE_FILE
ca_template $APPTYPE $CONSUL_CA_TEMPLATE_FILE

# Construct Server Cert Template.
basic_template $CONSUL_SERVER_CERT_TEMPLATE_FILE "consul_template_server_cert_pid_file"
server_cert_template $APPTYPE $CONSUL_SERVER_CERT_TEMPLATE_FILE

# Construct Server Cert Template.
basic_template $CONSUL_CLIENT_CERT_TEMPLATE_FILE "consul_template_client_cert_pid_file"
client_cert_template $APPTYPE $CONSUL_CLIENT_CERT_TEMPLATE_FILE

# Construct APP Template
basic_template $CONSUL_APP_TEMPLATE_FILE "consul_template_app_pid_file"
app_startup_template $APP $APPTYPE $DESTFILE $CONSUL_APP_TEMPLATE_FILE

for i in `ls /consul-template`
do
  chown burbank:burbank /consul-template/$i
  chmod 755 /consul-template/$i
done
