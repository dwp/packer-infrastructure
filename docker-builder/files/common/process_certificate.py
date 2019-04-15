import os, logging, sys, datetime,time

logging.basicConfig()
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

APPTYPE=os.environ['APPTYPE']
WhatToDo=sys.argv[1]
try:
    external_cert_arg = sys.argv[2]
except:
    external_cert_arg = "no"


def read_jks_password(jks_type,external_cert_arg):
    if jks_type == "truststore":
        with open("/home/burbank/.jks_truststore","r") as passwordfile:
            password = passwordfile.read().rstrip('\n')
    elif jks_type == "server_keystore":
        with open("/home/burbank/.server_jks_keystore","r") as passwordfile:
            password = passwordfile.read().rstrip('\n')
    elif jks_type == "client_keystore":
        with open("/home/burbank/.client_jks_keystore","r") as passwordfile:
            password = passwordfile.read().rstrip('\n')
    elif jks_type == "external_cert":
        with open("/home/burbank/." + external_cert_arg + "_jks_keystore","r") as passwordfile:
            password = passwordfile.read().rstrip('\n')
    return password

def nginx_reload():
    proc_list = os.popen("ps -Af").read()
    if "nginx" not in proc_list[:]:
        logger.info("No running nginx process found. It might be the first time this created")
        response = "No running nginx process"
    else:
        logger.info("Found a running nginx process. Reload the configuration")
        response = os.popen("/usr/sbin/nginx -s reload -c /opt/burbank/nginx.conf").read()
    return response

def jks_keystore(jks_type,external_cert_arg):
    if jks_type == "server":
        JKSFILE = "/opt/burbank/jks/server-keystore.jks"
        password = read_jks_password("server_keystore",external_cert_arg)
        key_file = "/opt/burbank/key/server.key"
        cert_file = "/opt/burbank/certs/server.cert"
    elif jks_type == "client":
        JKSFILE = "/opt/burbank/jks/client-keystore.jks"
        password = read_jks_password("client_keystore",external_cert_arg)
        key_file = "/opt/burbank/key/client.key"
        cert_file = "/opt/burbank/certs/client.cert"
    elif jks_type == "external_cert":
        JKSFILE = "/opt/burbank/jks/" + external_cert_arg + "-keystore.jks"
        password = read_jks_password("external_cert",external_cert_arg)
        cert_file = "/opt/burbank/certs/" + external_cert_arg + ".cert"
        key_file = "/opt/burbank/key/" + external_cert_arg + ".key"
    if external_cert_arg != "no":
        jks_store = jks_type + "-" + external_cert_arg
    else:
        jks_store = jks_type
    logger.info("Creating the " + jks_store + " Keystore")
    os.popen("openssl pkcs12 -export -out /opt/burbank/" + jks_store + ".pfx -inkey " + key_file + " -in " + cert_file + " -password pass:" + password)
    response = os.popen("keytool -noprompt -importkeystore -srckeystore /opt/burbank/" + jks_store + ".pfx -srcstoretype pkcs12 -srcstorepass " + password + " -destkeystore " + JKSFILE + " -deststoretype jks -deststorepass " + password).read()
    logger.debug(response)
    os.popen("rm /opt/burbank/" + jks_store + ".pfx")

def update_chain(type_of_cert):
    if type_of_cert == "server":
        cert_file_name = "/opt/burbank/certs/server.cert"
#    ca_certs = ["project_ca.crt","vault_server_int_ca.crt","burbank.working-age-int-ca.crt","burbank.working-age-ca.crt","ucd-ca.crt"]
    ca_certs = ["project_ca.crt","vault_server_int_ca.crt"]
    for cert in ca_certs:
        with open("/opt/burbank/ca_dir/" + cert,"r") as cacert:
            ca_cert_value = cacert.read()
        with open("/opt/burbank/certs/server.cert","a") as certfile:
            certfile.write("\n" + ca_cert_value)

def load_certificate(APPTYPE,type_of_cert,external_cert_arg):
    if type_of_cert == "server":
        cert_file_name = "/opt/burbank/certs/server.cert"
        key_file_name = "/opt/burbank/key/server.key"
        input_file = "/opt/burbank/certs/server-cert-file"
    elif type_of_cert == "client":
        cert_file_name = "/opt/burbank/certs/client.cert"
        key_file_name = "/opt/burbank/key/client.key"
        input_file = "/opt/burbank/certs/client-cert-file"
    elif type_of_cert == "external_cert":
        cert_file_name = "/opt/burbank/certs/" + external_cert_arg + ".cert"
        key_file_name = "/opt/burbank/key/" + external_cert_arg + ".key"
        input_file = "/opt/burbank/certs/" + external_cert_arg + "-cert-file"
        while not os.path.exists(input_file):
            logger.info("Waiting till the " + input_file + " is created")
            time.sleep(5)
    start_cert = "#Start Cert Section\n"
    end_cert = "#End Cert Section"
    start_key = "#Start Key Section\n"
    end_key = "#End Key Section"
    data =  open(input_file,"r").read()
    logger.info("Creating the " + type_of_cert + " Certifcate files")

    if os.path.exists(cert_file_name):
        os.popen("cp " + cert_file_name + " " + cert_file_name + ".bak")
    with open(cert_file_name,"w") as pubcertfile:
            certificate = ((data.split(start_cert)[1].split(end_cert)[0]))
            pubcertfile.write(certificate)
            os.chmod(cert_file_name,0755)

    if os.path.exists(key_file_name):
        os.popen("cp " + key_file_name + " " + key_file_name + ".bak")
    with open(key_file_name,"w") as privatekeyfile:
            private_key = ((data.split(start_key)[1].split(end_key)[0]))
            privatekeyfile.write(private_key)
            os.chmod(key_file_name,0600)

    if APPTYPE == "java":
        if type_of_cert == "server":
            jks_keystore("server",external_cert_arg)
        elif type_of_cert == "client":
            jks_keystore("client",external_cert_arg)
        elif type_of_cert == "external_cert":
            jks_keystore("external_cert",external_cert_arg)
    elif APPTYPE == "nginx":
        response = nginx_reload()
        logger.debug(response)
    elif APPTYPE == "nodejs":
        if type_of_cert == "server":
            update_chain("server")
    else:
        logger.info("No additional action mentioned for " + APPTYPE + " when certificate changes")


def truststore(APPTYPE):
    if APPTYPE == "java":
        logger.info("Adding Trusted CA entries to TrustStore, Server Keystore and Client Keystore")
        time_now = datetime.datetime.now()
        updated_on="updated-on-" + time_now.strftime("%d-%m-%Y-%H-%M-%S")
        trust_pass = read_jks_password("truststore","no")
        server_pass = read_jks_password("server_keystore","no")
        client_pass = read_jks_password("client_keystore","no")
        for trustedca in os.listdir("/opt/burbank/ca_dir"):
            alias_name = trustedca + "-" + updated_on
            response = os.popen("keytool -noprompt -importcert -trustcacerts -keystore /opt/burbank/jks/truststore.jks -alias "+ alias_name + " -storepass " + trust_pass + " -file /opt/burbank/ca_dir/" + trustedca).read()
            logger.debug (response)
            if trustedca == "project_ca.crt":
                response = os.popen("keytool -noprompt -importcert -trustcacerts -keystore /opt/burbank/jks/server-keystore.jks -alias "+ alias_name + " -storepass " + server_pass + " -file /opt/burbank/ca_dir/" + trustedca).read()
                logger.debug (response)
                response = os.popen("keytool -noprompt -importcert -trustcacerts -keystore /opt/burbank/jks/client-keystore.jks -alias "+ alias_name + " -storepass " + client_pass + " -file /opt/burbank/ca_dir/" + trustedca).read()
                logger.debug (response)
    elif APPTYPE == "nginx":
        response = nginx_reload()
        logger.debug(response)
    else:
        logger.info("No need to do anything as there is no action mentioned for " + APPTYPE + " when CA Certificate changes")

def external_certificate(APPTYPE,external_cert_arg):
    if APPTYPE == "java":
        logger.info("Adding CA Certs to the KeyStore")
        time_now = datetime.datetime.now()
        updated_on="updated-on-" + time_now.strftime("%d-%m-%Y-%H-%M-%S")
        ca_certs = os.popen("ls /opt/burbank/ca_dir/" + external_cert_arg + "*").read().split('\n')
        key_file = "/opt/burbank/key/" + external_cert_arg + ".key"
        cert_file = "/opt/burbank/certs/" + external_cert_arg + ".cert"
        keystore_pass = read_jks_password("external_cert",external_cert_arg)
        for ca in ca_certs:
            if ca != "":
                alias_name = ca + "-" + updated_on
                response = os.popen("keytool -noprompt -importcert -trustcacerts -keystore /opt/burbank/jks/" + external_cert_arg + "-keystore.jks -alias "+ alias_name + " -storepass " + keystore_pass + " -file " + ca).read()
                logger.debug(response)

# Make sure the necessary Directories are available
required_dirs = ["/opt/burbank/certs","/opt/burbank/key","/opt/burbank/jks"]
for directory in required_dirs:
    if not os.path.exists(directory):
        logger.info("Creating Directory " + directory)
        os.mkdir(directory)
    else:
        logger.info("Required Directory " + directory + " found")

if WhatToDo == "truststore":
    logger.info("Request received for TrustStore")
    truststore(APPTYPE)
elif WhatToDo == "server_cert":
    logger.info("Request received for Server Certificate")
    load_certificate(APPTYPE,"server",external_cert_arg)
elif WhatToDo == "client_cert":
    logger.info("Request received for Client Certificate")
    load_certificate(APPTYPE,"client",external_cert_arg)
elif WhatToDo == "external_cert":
    logger.info("Request received for External Certificate " + external_cert_arg )
    load_certificate(APPTYPE,"external_cert",external_cert_arg)
    external_certificate(APPTYPE,external_cert_arg)
else:
    logger.error("No Request Received")
