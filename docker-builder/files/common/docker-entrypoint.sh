#!/bin/sh
set -e

# This will be the Entrypoint script for all services
# Step 1 is to make the Vault Agent Start

# Check if the required environment variables are passed in docker
if [[ -z $VAULT_ADDR || -z $VAULT_CAPATH || -z $VAULT_CACERT ||  -z $PROJECT ||  -z $ENVIRONMENT ||  -z $APP ||  -z $SERVER_COMMON_NAME ||  -z $CLIENT_COMMON_NAME || -z $LOG_LEVEL || -z $APP_VERSION ]]; then
  echo "ERROR: One or all VAULT_ADDR,VAULT_CAPATH,VAULT_CACERT,PROJECT, ENVIRONMENT, APP, SERVER_COMMON_NAME, LOG_LEVEL,APP_VERSION  and CLIENT_COMMON_NAME environment variables are not present"
  exit 1
else
  echo "INFO: All VAULT_ADDR,VAULT_CAPATH,VAULT_CACERT,PROJECT, ENVIRONMENT, APP, SERVER_COMMON_NAME,LOG_LEVEL,APP_VERSION and CLIENT_COMMON_NAME environment environment variables are present"
fi

if [[ -z $SERVER_SANS ]]; then
  echo "INFO: SANS are Empty"
fi

if [ -z $APPTYPE ]; then
  echo "INFO: APPTYPE environment variable is null. Assuming that it is not a Java App"
else
  echo "INFO: APPTYPE environment variable is set to $APPTYPE"
fi

if [[ -z "${APP_STARTUP_OPTIONS}" ]]; then
  echo "INFO: No APP Startup Options provided"
else
  echo "INFO: APP StartUP Options are ${APP_STARTUP_OPTIONS}"
fi

# Set the Environment variables of Log Levels of Vault Agent and Consul Template. If nothing set, make it to info
if [[ -z $VAULT_CLIENT_LOG_LEVEL ]]; then
   VAULT_CLIENT_LOG_LEVEL="info"
fi
echo "INFO: VAULT Client Log Level is set to $VAULT_CLIENT_LOG_LEVEL"
if [[ -z $CONSUL_TEMPLATE_LOG_LEVEL ]]; then
   CONSUL_TEMPLATE_LOG_LEVEL="info"
fi
echo "INFO: Consul Template Log Level is set to $CONSUL_TEMPLATE_LOG_LEVEL"
echo "INFO: App Log Level is set to $LOG_LEVEL"

# Check if the required tmpfs filesystems present
if [ `df -h | grep "tmpfs" | grep -i burbank | wc -l` -eq 2 ]; then
  echo "INFO: tmpfs filesystems are present"
else
  echo "ERROR: Required tmpfs filesystems are not present. Cannot proceed further"
  exit 1
fi

echo "INFO: Configuring the Vault Agent for Docker"
VAULT_AWS_PATH="auth/auth-aws-$PROJECT-$ENVIRONMENT"
VAULT_AUTH_ROLE="$APP-role"
cp /vault_client/auto-auth/docker.hcl.tmpl /home/burbank/docker.hcl
sed -i 's@VAULT_AWS_PATH@'"$VAULT_AWS_PATH"'@g' /home/burbank/docker.hcl
sed -i 's@VAULT_AUTH_ROLE@'"$VAULT_AUTH_ROLE"'@g' /home/burbank/docker.hcl

echo "INFO: Starting the Vault Agent"
vault agent -config /home/burbank/docker.hcl -log-level=$VAULT_CLIENT_LOG_LEVEL > /dev/console 2>&1 &

sleep 2
WAIT_COUNT=10
echo "INFO : Count down to 10 to see if the Vault Authentication is successful"
while [ $WAIT_COUNT -gt 0 ];
do
  if [ -f /home/burbank/.vault-token ]; then
    echo "INFO: Vault Token is present"
    break
  else
    echo "ERROR: Check after 5 secs......."
    sleep 5
    WAIT_COUNT=`expr $WAIT_COUNT - 1`
    echo "Count Down : $WAIT_COUNT "
  fi
done

if [ $WAIT_COUNT -eq 0 ]; then
  echo "ERROR: Vault Agent is not started. Cannot proceed further"
  exit 1
fi

echo "INFO: Constructing the Vault PKI Parameters"
VAULT_PKI_PATH="/secrets-pki-$PROJECT-$ENVIRONMENT"
VAULT_PKI_SERVER_ROLE="$APP-server-role"
VAULT_PKI_CLIENT_ROLE="$APP-client-role"
VAULT_INT_PATH="/secrets-pki-int-ca"
APPNAME="$APP"

echo "INFO: Configure the CA Template"
mkdir -p /opt/burbank/ca_dir
#cp /etc/ssl/burbank_all_ca /opt/burbank/ca.tmpl
cp /etc/ssl/burbank_ca/* /opt/burbank/ca_dir/
#echo "{{ with secret \"$VAULT_PKI_PATH/cert/ca\" }}{{ .Data.certificate }}{{ end }}" >> /opt/burbank/ca.tmpl
#echo -e "\n{{ with secret \"$VAULT_INT_PATH/cert/ca\" }}{{ .Data.certificate }}{{ end }}" >> /opt/burbank/ca.tmpl
echo "{{ with secret \"$VAULT_PKI_PATH/cert/ca\" }}{{ .Data.certificate }}{{ end }}" >> /opt/burbank/ca.tmpl
echo -e "\n{{ with secret \"$VAULT_INT_PATH/cert/ca\" }}{{ .Data.certificate }}{{ end }}" >> /opt/burbank/ca.tmpl
for i in burbank.working-age-int-ca.crt burbank.working-age-ca.crt ucd-ca.crt
do
  echo -e "\n" >> /opt/burbank/ca.tmpl
  cat /etc/ssl/burbank_ca/$i >> /opt/burbank/ca.tmpl
done

if [ ! -d /opt/burbank/certs ]; then
  mkdir -p /opt/burbank/certs
fi

for i in ca-configuration.hcl.tmpl server-cert-configuration.hcl.tmpl client-cert-configuration.hcl.tmpl
do
echo "INFO: Preparing $i"
hcl_file=$(echo $i | awk -F ".tmpl" '{print $1}')
echo "INFO: Copying $i to /home/burbank/$hcl_file"
cp /consul-template/$i /home/burbank/$hcl_file
done

# Get the external-certs list . Reboot is required if any new external-certs , replacing existing ones will be taken care by default
echo "INFO: Checking if there any configurations required for external certificate"
cat << EOF >> /home/burbank/external-certs.tmpl
{{ range secrets "/secrets-$PROJECT-$ENVIRONMENT/infra/$APP/external-certs/" }}{{ . }}
{{ end }}
EOF
consul-template -template "/home/burbank/external-certs.tmpl:/home/burbank/external-certs-list" -once

if [[ `cat /home/burbank/external-certs-list | wc -w` -ne 0 ]]; then
    echo "INFO: There are external certs needed for this . Creating Consul Templates for this"
    echo "INFO: Getting the number of CA Certs it has"
    for i in `cat /home/burbank/external-certs-list`
    do
cat << EOF > /home/burbank/ca-cert-count.tmpl
{{ with secret "/secrets-$PROJECT-$ENVIRONMENT/infra/$APP/external-certs/$i" }}{{ range \$key,\$value := .Data }}{{ if \$key | contains "ca_cert" }}{{ \$key }}
{{ end }}{{ end }}{{ end }}
EOF
    consul-template -template "/home/burbank/ca-cert-count.tmpl:/home/burbank/$i-ca-cert-count" -once
    done
    rm /home/burbank/ca-cert-count.tmpl
    echo "INFO: Putting the CA in single file"
    echo -e "\n" >> /opt/burbank/ca.tmpl
    # Single File
    for i in `cat /home/burbank/external-certs-list`
    do
cat << EOF >> /opt/burbank/ca.tmpl
{{ with secret "/secrets-$PROJECT-$ENVIRONMENT/infra/$APP/external-certs/$i" }}{{ range \$key,\$value := .Data }}{{ if \$key | contains "ca_cert" }}
{{ \$value }}
{{ end }}{{ end }}{{ end }}
EOF
    done
    # CA Directory
    echo "INFO: Putting the CA's in the CA directory"
    for i in `cat /home/burbank/external-certs-list`
    do
      if [[ `cat /home/burbank/$i-ca-cert-count | wc -w` -ne 0 ]]; then
        for j in `cat /home/burbank/$i-ca-cert-count`
        do
cat << EOF >> /home/burbank/ca-configuration.hcl
template {
  contents="{{ with secret \"/secrets-$PROJECT-$ENVIRONMENT/infra/$APP/external-certs/$i\" }}{{ .Data.$j }}{{ end }}"
  destination="/opt/burbank/ca_dir/${i}_${j}.crt"
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
EOF
        done
      fi
    done

# Create a Template for External Certs
cat << EOF >>/home/burbank/external-certs-configuration.hcl
reload_signal = "SIGHUP"
kill_signal = "SIGINT"
max_stale = "10m"
log_level = "$CONSUL_TEMPLATE_LOG_LEVEL"
pid_file = "/home/burbank/external_certs_configuration_pid_file"
wait {
  min = "60s"
  max = "180s"
}
EOF
for i in `cat /home/burbank/external-certs-list`
do
cat << EOF >> /opt/burbank/certs/$i-cert.tmpl
#Start Cert Section
{{ with secret "/secrets-$PROJECT-$ENVIRONMENT/infra/$APP/external-certs/$i" }}{{ .Data.certificate }}{{ end }}
#End Cert Section
#Start Key Section
{{ with secret "/secrets-$PROJECT-$ENVIRONMENT/infra/$APP/external-certs/$i" }}{{ .Data.private_key }}{{ end }}
#End Key Section
EOF
cat << EOF >> /home/burbank/external-certs-configuration.hcl
template {
  source = "/opt/burbank/certs/$i-cert.tmpl"
  destination = "/opt/burbank/certs/$i-cert-file"
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
  command = "python /usr/local/bin/process_certificate.py external_cert $i"
}
EOF
done
else
    echo "INFO: There are no external certs needed for this"
fi

echo "INFO: Configuring the Server Cert Template"
cat << EOF >> /opt/burbank/certs/server-cert.tmpl
#Start Cert Section
{{ with secret "$VAULT_PKI_PATH/issue/$VAULT_PKI_SERVER_ROLE" "common_name=$SERVER_COMMON_NAME" "alt_names=$SERVER_SANS" }}{{ .Data.certificate }}{{ end }}
#End Cert Section
#Start Key Section
{{ with secret "$VAULT_PKI_PATH/issue/$VAULT_PKI_SERVER_ROLE" "common_name=$SERVER_COMMON_NAME" "alt_names=$SERVER_SANS" }}{{ .Data.private_key }}{{ end }}
#End Key Section
EOF

echo "INFO: Configuring the Client Cert Template"
cat << EOF >> /opt/burbank/certs/client-cert.tmpl
#Start Cert Section
{{ with secret "$VAULT_PKI_PATH/issue/$VAULT_PKI_CLIENT_ROLE" "common_name=$CLIENT_COMMON_NAME" }}{{ .Data.certificate }}{{ end }}
#End Cert Section
#Start Key Section
{{ with secret "$VAULT_PKI_PATH/issue/$VAULT_PKI_CLIENT_ROLE" "common_name=$CLIENT_COMMON_NAME" }}{{ .Data.private_key }}{{ end }}
#End Key Section
EOF

if [ $APPTYPE = "java" ]; then
echo "INFO: Generating KeyStore and TrustStore Passwords"
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -1 > /home/burbank/.server_jks_keystore
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -1 > /home/burbank/.client_jks_keystore
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -1 > /home/burbank/.jks_truststore
if [[ `cat /home/burbank/external-certs-list | wc -w` -ne 0 ]]; then
  for i in `cat /home/burbank/external-certs-list`
  do
    echo "INFO: Generating KeyStore passwords for external cert of $i"
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -1 > /home/burbank/.${i}_jks_keystore
  done
fi
fi

for i in ca-configuration.hcl.tmpl server-cert-configuration.hcl.tmpl client-cert-configuration.hcl.tmpl
do
hcl_file=$(echo $i | awk -F ".tmpl" '{print $1}')
sed -i 's@VAULT_PKI_PATH@'"$VAULT_PKI_PATH"'@g' /home/burbank/$hcl_file
sed -i 's@VAULT_PKI_SERVER_ROLE@'"$VAULT_PKI_SERVER_ROLE"'@g' /home/burbank/$hcl_file
sed -i 's@VAULT_PKI_CLIENT_ROLE@'"$VAULT_PKI_CLIENT_ROLE"'@g' /home/burbank/$hcl_file
sed -i 's@SERVER_COMMON_NAME@'"$SERVER_COMMON_NAME"'@g' /home/burbank/$hcl_file
sed -i 's@CLIENT_COMMON_NAME@'"$CLIENT_COMMON_NAME"'@g' /home/burbank/$hcl_file
sed -i 's@SERVER_SANS@'"$SERVER_SANS"'@g' /home/burbank/$hcl_file
sed -i 's@VAULT_ADDR@'"$VAULT_ADDR"'@g' /home/burbank/$hcl_file
sed -i 's@VAULT_CACERT@'"$VAULT_CACERT"'@g' /home/burbank/$hcl_file
sed -i 's@VAULT_INT_PATH@'"$VAULT_INT_PATH"'@g' /home/burbank/$hcl_file
sed -i 's@CONSUL_TEMPLATE_LOG_LEVEL@'"$CONSUL_TEMPLATE_LOG_LEVEL"'@g' /home/burbank/$hcl_file

echo "INFO: Starting the Consul Template of /home/burbank/$hcl_file ......"
consul-template -config /home/burbank/$hcl_file >/dev/console 2>&1 &
done

if [[ `cat /home/burbank/external-certs-list | wc -w` -ne 0 ]]; then
  echo "INFO: Starting the External Certificate configuration Template"
  consul-template -config /home/burbank/external-certs-configuration.hcl >/dev/console 2>&1 &
fi

echo "INFO : Replace Project, Environment and APP variables in the app server configuration template"
if [[ $APPTYPE = "nginx" ]]; then
cp /opt/nginx/properties/server-config.ctmpl /opt/burbank/app-config.ctmpl
else
cp /opt/$APP/properties/server-config.ctmpl /opt/burbank/app-config.ctmpl
fi
sed -i 's@PROJECT@'"$PROJECT"'@g' /opt/burbank/app-config.ctmpl
sed -i 's@ENVIRONMENT@'"$ENVIRONMENT"'@g' /opt/burbank/app-config.ctmpl
sed -i 's@APP@'"$APP"'@g' /opt/burbank/app-config.ctmpl
sed -i 's@VERSION@'"$APP_VERSION"'@g' /opt/burbank/app-config.ctmpl

echo "INFO: Checking if all Certs and Keys are created......"
for i in certs/server.cert certs/client.cert key/server.key key/client.key
do
  WAIT_COUNT=10
  echo "INFO : Count down to 10 to see if $i is created"
  while [ $WAIT_COUNT -gt 0 ];
  do
    if [ -f /opt/burbank/$i ]; then
      echo "INFO: /opt/burbank/$i is created"
      break
    else
      echo "ERROR: Check after 5 secs for creation of $i......."
      sleep 5
      WAIT_COUNT=`expr $WAIT_COUNT - 1`
      echo "Count Down : $WAIT_COUNT for $i"
    fi
  done

  if [ $WAIT_COUNT -eq 0 ]; then
    echo "ERROR: /opt/burbank/$i is not created. Cannot proceed further"
    exit 1
  fi
done

if [[ `cat /home/burbank/external-certs-list | wc -w` -ne 0 ]]; then
  for i in `cat /home/burbank/external-certs-list`
  do
    for j in certs/$i.cert key/$i.key
    do
      WAIT_COUNT=10
      echo "INFO : Count down to 10 to see if $j is created"
      while [ $WAIT_COUNT -gt 0 ];
      do
        if [ -f /opt/burbank/$j ]; then
          echo "INFO: /opt/burbank/$j is created"
          break
        else
          echo "ERROR: Check after 5 secs for creation of $j......."
          sleep 5
          WAIT_COUNT=`expr $WAIT_COUNT - 1`
          echo "Count Down : $WAIT_COUNT for $j"
        fi
      done
      if [ $WAIT_COUNT -eq 0 ]; then
        echo "ERROR: /opt/burbank/$j is not created. Cannot proceed further"
        exit 1
      fi
    done
  done
fi

if [ $APPTYPE = "java" ]; then
  echo "INFO: Checking if Keystore and TrustStore are created"
  for i in jks/server-keystore.jks jks/client-keystore.jks jks/truststore.jks
  do
    WAIT_COUNT=10
    echo "INFO : Count down to 10 to see $i is created"
    while [ $WAIT_COUNT -gt 0 ];
    do
      if [ -f /opt/burbank/$i ]; then
        echo "INFO: /opt/burbank/$i is created"
        break
      else
        echo "ERROR: Check after 5 secs for creation of $i......."
        sleep 5
        WAIT_COUNT=`expr $WAIT_COUNT - 1`
        echo "Count Down : $WAIT_COUNT for $i"
      fi
    done

    if [ $WAIT_COUNT -eq 0 ]; then
      echo "ERROR: /opt/burbank/$i is not created. Cannot proceed further"
      exit 1
    fi
  done
  if [[ `cat /home/burbank/external-certs-list | wc -w` -ne 0 ]]; then
    for i in `cat /home/burbank/external-certs-list`
    do
      for j in jks/$i-keystore.jks
      do
        WAIT_COUNT=10
        echo "INFO : Count down to 10 to see if $j is created"
        while [ $WAIT_COUNT -gt 0 ];
        do
          if [ -f /opt/burbank/$j ]; then
            echo "INFO: /opt/burbank/$j is created"
            break
          else
            echo "ERROR: Check after 5 secs for creation of $j......."
            sleep 5
            WAIT_COUNT=`expr $WAIT_COUNT - 1`
            echo "Count Down : $WAIT_COUNT for $j"
          fi
        done
        if [ $WAIT_COUNT -eq 0 ]; then
          echo "ERROR: /opt/burbank/$j is not created. Cannot proceed further"
          exit 1
        fi
      done
    done
  fi
fi

if [[ $APPTYPE = "nginx" ]]; then
  openssl dhparam -dsaparam -out /opt/burbank/key/dhparam.key 4096
fi

echo "INFO: Preparing the APP Startup Template"
cp /consul-template/app-startup.hcl.tmpl /home/burbank/app-startup.hcl
sed -i 's@CONSUL_TEMPLATE_LOG_LEVEL@'"$CONSUL_TEMPLATE_LOG_LEVEL"'@g' /home/burbank/app-startup.hcl
if [[ -z "${APP_STARTUP_OPTIONS}" ]]; then
sed -i 's@APP_STARTUP_OPTIONS@'""'@g' /home/burbank/app-startup.hcl
else
sed -i 's@APP_STARTUP_OPTIONS@'"$APP_STARTUP_OPTIONS"'@g' /home/burbank/app-startup.hcl
fi

echo "INFO: Starting the Application......"
consul-template -config /home/burbank/app-startup.hcl >/dev/console 2>&1
