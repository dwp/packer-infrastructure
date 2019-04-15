#!/usr/bin/python
'''
 ____________________________________________________________________________
| About   : This sets up the required Vault Client configuration on AWS EC2  |
| Author  : Arun Jayanth,  H&W Team, Burbank                                 |
| Purpose : To Be used along with Burbank's Packer AMI Builder Script        |
 ____________________________________________________________________________
|                       REQUIRED INPUT VARIABLES                             |
 ----------------------------------------------------------------------------
| REGION            = Region which the ECR image will be taken from.         |
| ENCRYPTION_STATUS = Vault Auto Auth Agent Encryption status. true or false |
| VAULT_VERSION     = Version of Vault to use. Binds with Each AMI           |
| VAULT_LICENSE     = License of Vault . opensource or enterprise            |
| OWNER             = user and group ownership                               |
| HASHICORP_GPG_KEY = GPG Key for HashiCorp's Download                       |
 ____________________________________________________________________________
'''
import os,sys,base64,json,random,string,boto3,hashlib,urllib,zipfile

# Set the Required Environment Variables
REGION = os.environ['REGION']
try:
    encryption_status = os.environ['ENCRYPTION_STATUS']
except:
    encryption_status = "false"
VAULT_VERSION = os.environ['VAULT_VERSION']
VAULT_LICENSE = os.environ['VAULT_LICENSE']
OWNER = os.environ['OWNER']
HASHICORP_GPG_KEY = os.environ['HASHICORP_GPG_KEY']

# Download the GPG Key from GPG Server
for server in ["hkp://p80.pool.sks-keyservers.net:80","hkp://keyserver.ubuntu.com:80","hkp://pgp.mit.edu:80"]:
    response = os.popen("gpg --keyserver "+ server + " --recv-keys " + HASHICORP_GPG_KEY)
    exit_status = response.close()
    if str(exit_status) == "None":
        break

# Install the Vault Agent
if VAULT_LICENSE == "enterprise":
    download_link_prefix = "https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/vault/ent/" + VAULT_VERSION + "/vault-enterprise_" + VAULT_VERSION + "%2Bent_"
elif VAULT_LICENSE == "opensource":
    download_link_prefix = "https://releases.hashicorp.com/vault/" + VAULT_VERSION + "/vault_" + VAULT_VERSION + "_"

files_to_download = ["linux_amd64.zip","SHA256SUMS","SHA256SUMS.sig"]
for to_download in files_to_download:
    print ("Download file: " + to_download)
    urllib.urlretrieve(download_link_prefix + to_download , "/tmp/" + to_download)

response = os.popen("gpg --batch --verify /tmp/SHA256SUMS.sig /tmp/SHA256SUMS")
exit_status = response.close()
if str(exit_status) != "None":
    print("ERROR: Cannot proceed further as Signature cannot be verified in the download")
    sys.exit(1)

searchfile = open("/tmp/SHA256SUMS", "r")
for line in searchfile:
    if "linux_amd64" in line:
        received_checksum = line.split()[0]

filename = "/tmp/linux_amd64.zip"
sha256_hash = hashlib.sha256()
with open(filename,"rb") as f:
    for byte_block in iter(lambda: f.read(4096),b""):
        sha256_hash.update(byte_block)
    downloaded_checksum = sha256_hash.hexdigest()

if received_checksum != downloaded_checksum:
    print("ERROR: Checksum is not the same. Cannot proceed further")
    sys.exit(1)

zip_ref = zipfile.ZipFile('/tmp/linux_amd64.zip', 'r')
zip_ref.extractall('/usr/local/bin')
zip_ref.close()
os.system("chmod 755 /usr/local/bin/vault")
files_to_remove = ["linux_amd64.zip","SHA256SUMS","SHA256SUMS.sig"]
for to_remove in files_to_remove:
    print ("Removing file: " + to_remove)
    os.system("rm /tmp/"+ to_remove)

# Step 1 : Create the Required Directories. Assuming FS and IP Tables are set as per the README.md
if not os.path.isdir("/vault_client/details"):
    os.makedirs("/vault_client/details")

if not os.path.isdir("/vault_client/auto-auth"):
    os.makedirs("/vault_client/auto-auth")

#Step 2: Configure the Vault Auto Auth Agent Template
vault_auto_auth_unencryted_template = """pid_file = "VAULT_PID_FILE"
exit_after_auth = false
auto_auth {
        method "aws" {
                mount_path = "VAULT_AWS_PATH"
                config = {
                        type = "iam"
                        role = "VAULT_AUTH_ROLE"
                        header_value = "VAULT_SERVER"
                }
        }
        sink "file" {
                config = {
                        path = "VAULT_TOKEN_PATH"
                }
        }
}"""
vault_auto_auth_encryted_template = """pid_file = "VAULT_PID_FILE"
exit_after_auth = false
auto_auth {
        method "aws" {
                mount_path = "VAULT_AWS_PATH"
                config = {
                        type = "iam"
                        role = "VAULT_AUTH_ROLE"
                        header_value = "VAULT_SERVER"
                }
        }
        sink "file" {
                dh_type = "curve25519"
                add_env_var = "AAD_VALUE"
                dh_path = "/vault_client/details/publickey.json"
                config = {
                        path = "VAULT_TOKEN_PATH"
                }
        }
}"""

AMI_TYPES = ["infra","docker"]
for TYPE in AMI_TYPES:
    if encryption_status == "false":
        template = vault_auto_auth_unencryted_template
    else:
        template = vault_auto_auth_encryted_template

    if TYPE == "infra":
        template_path = "/vault_client/auto-auth/agent.hcl.tmpl"
        VAULT_TOKEN_PATH = "/root/.vault-token"
        VAULT_PID_FILE = "/vault_client/auto-auth/vault_agent_pid_file"
    elif TYPE == "docker":
        template_path = "/vault_client/auto-auth/docker.hcl.tmpl"
        VAULT_TOKEN_PATH = "/home/" + OWNER + "/.vault-token"
        VAULT_PID_FILE = "/home/" + OWNER + "/vault_agent_pid_file"
    template = template.replace("VAULT_PID_FILE",VAULT_PID_FILE)
    template = template.replace("VAULT_TOKEN_PATH",VAULT_TOKEN_PATH)

    with open(template_path,'w') as vaultauto:
        vaultauto.write(template)

# Step 3: Only if Encryption is true, generate some random string for PublicKey and AAD

if encryption_status == "true":
    random_byte = {}
    random_byte["curve25519_public_key"] = base64.b64encode(os.urandom(32))
    curve25519_pub_file = open("/vault_client/details/publickey.json","w")
    curve25519_pub_file.write(json.dumps(random_byte))
    curve25519_pub_file.close()

    random = ''.join([random.choice(string.ascii_letters + string.digits) for n in xrange(16)])
    enc_details = open("/vault_client/details/aes_enc_details","w")
    enc_details.write('export AAD_VALUE="' + random + '"')
    enc_details.close

# Step 4: Prepare the Script to execute this python script before vault auto auth agent startup
'''
Configure this as a Systemd service and make this as a dependency service for the Vault Auto Auth Agent
'''
python_template_script="""#!/usr/bin/python
import os, boto3, socket
instance_id = os.popen('curl http://169.254.169.254/latest/meta-data/instance-id/').read()

ec2_client = boto3.client('ec2',region_name='REGION')
response = ec2_client.describe_instances(
    InstanceIds = [
        instance_id
    ]
)
tags = response['Reservations'][0]['Instances'][0]['Tags']
count = 0
value_count = 0
VAULT_SERVER = "VAULT_SERVER"
VAULT_PORT = "VAULT_PORT"
VAULT_AWS_PATH = "VAULT_AWS_PATH"
VAULT_AUTH_ROLE = "VAULT_AUTH_ROLE"
while count < len(tags):
    if tags[count]['Key'] == "VAULT_SERVER":
        VAULT_SERVER = tags[count]['Value']
        value_count += 1
    elif tags[count]['Key'] == "VAULT_PORT":
        VAULT_PORT = tags[count]['Value']
        value_count += 1
    elif tags[count]['Key'] == "VAULT_AWS_PATH":
        VAULT_AWS_PATH = tags[count]['Value']
        value_count += 1
    elif tags[count]['Key'] == "VAULT_AUTH_ROLE":
        VAULT_AUTH_ROLE = tags[count]['Value']
        value_count += 1

    if value_count == 4:
        break
    else:
        count += 1

# Write the Vault details to source it
HOSTNAME=socket.gethostname()
vault_details = open("/vault_client/details/server_details", "w")
vault_details.writelines(['VAULT_ADDR="https://' + VAULT_SERVER + ':' + VAULT_PORT + '"' +'\\n' , 'VAULT_CAPATH="/etc/ssl/?????"' +'\\n', 'HOSTNAME="' + HOSTNAME + '"'])
vault_details.close()

# Write the Vault Agent File
template_files = ["agent.hcl.tmpl","docker.hcl.tmpl"]
for templ in template_files:
    vault_agent = open("/vault_client/auto-auth/" + templ ,"r")
    vault_agent_data = vault_agent.read()
    vault_agent_data = vault_agent_data.replace("VAULT_SERVER",VAULT_SERVER)
    vault_agent.close()
    if templ == "agent.hcl.tmpl":
        vault_agent = open("/vault_client/auto-auth/agent.hcl","w")
    else:
        vault_agent = open("/vault_client/auto-auth/docker.hcl.tmpl","w")
    vault_agent.write(vault_agent_data)
    vault_agent.close()
    os.system("chown -R burbank:burbank /vault_client")
    os.system("chmod -R 755 /vault_client")
"""
python_template_script = python_template_script.replace('REGION',REGION)
with open("/vault_client/auto-auth/tag_replace.py","w") as vaulttagfile:
    vaulttagfile.write(python_template_script)

vault_client_env_file_systemd = """[Unit]
Description=Vault Client Environment File Setup Service
After=cloudwatchlogs-env-file-setup.service
Requires=cloudwatchlogs-env-file-setup.service

[Service]
TimeoutStartSec=0
Restart=on-failure
RemainAfterExit=yes
RestartSec=5
SuccessExitStatus=0
ExecStartPre=/bin/sleep 10
ExecStart=-/usr/bin/python /vault_client/auto-auth/tag_replace.py

[Install]
WantedBy=multi-user.target
"""
with open("/etc/systemd/system/vault-client-env-setup.service","w") as systemdfile:
    systemdfile.write(vault_client_env_file_systemd)
os.system("systemctl daemon-reload")
os.system("systemctl enable vault-client-env-setup.service")

# Step 5 : Make the Tag replacement Python script as a pre script for Vault Auth Systemd
# This will be running, but won't start until the tag start_ec2_vault_client to `yes` and the environment should not be prod


vault_client_start_script = """#!/usr/bin/python
import os,boto3,sys
instance_id = os.popen('curl http://169.254.169.254/latest/meta-data/instance-id/').read()
ec2_client = boto3.client('ec2',region_name='REGION')
response = ec2_client.describe_instances(
    InstanceIds = [
        instance_id
    ]
)
tags = response['Reservations'][0]['Instances'][0]['Tags']
count = 0
value_count = 0
VAULT_AWS_PATH = "VAULT_AWS_PATH"
VAULT_AUTH_ROLE = "VAULT_AUTH_ROLE"
start_ec2_vault_client = "no"
while count < len(tags):
    if tags[count]['Key'] == "start_ec2_vault_client":
        start_ec2_vault_client = tags[count]['Value'].lower()
        value_count += 1
    elif tags[count]['Key'] == "VAULT_AWS_PATH":
        VAULT_AWS_PATH = tags[count]['Value']
        value_count += 1
    elif tags[count]['Key'] == "VAULT_AUTH_ROLE":
        VAULT_AUTH_ROLE = tags[count]['Value']
        value_count += 1
    elif tags[count]['Key'] == "Environment" or tags[count]['Key'] == "environment":
        ENVIRONMENT = tags[count]['Value']
        value_count += 1
    if value_count == 4:
        break
    else:
        count += 1
if start_ec2_vault_client == "yes":
    vault_agent = open("/vault_client/auto-auth/agent.hcl" ,"r")
    vault_agent_data = vault_agent.read()
    vault_agent_data = vault_agent_data.replace("VAULT_AWS_PATH",VAULT_AWS_PATH)
    vault_agent_data = vault_agent_data.replace("VAULT_AUTH_ROLE",VAULT_AUTH_ROLE)
    vault_agent.close()
    vault_agent = open("/vault_client/auto-auth/agent.hcl","w")
    vault_agent.write(vault_agent_data)
    vault_agent.close()
    os.system("chown -R burbank:burbank /vault_client")
    os.system("chmod -R 755 /vault_client")
    os.system("set -a && source /vault_client/details/server_details && vault agent -config /vault_client/auto-auth/agent.hcl")
elif start_ec2_vault_client == "no":
    print("INFO: Vault will not be started as it is not requested to start")
    sys.exit(0)
"""
vault_client_start_script = vault_client_start_script.replace('REGION',REGION)
with open("/vault_client/auto-auth/ec2_start_client.py","w") as scriptfile:
    scriptfile.write(vault_client_start_script)

os.system("chown -R burbank:burbank /vault_client")
os.system("chmod -R 755 /vault_client")

vault_auto_auth_systemd = """[Unit]
Description=Vault Auto Auth Agent Service
After=cloudwatchlogs-env-file-setup.service vault-client-env-setup.service
Requires=cloudwatchlogs-env-file-setup.service vault-client-env-setup.service

[Service]
EnvironmentFile=-/vault_client/details/server_details
EnvironmentFile=-/etc/cloudwatchlogs.config
TimeoutStartSec=0
Restart=always
ExecStart=-/usr/bin/python /vault_client/auto-auth/ec2_start_client.py

[Install]
WantedBy=multi-user.target
"""

with open("/etc/systemd/system/start-ec2-vault-client.service","w") as systemdfile:
    systemdfile.write(vault_auto_auth_systemd)
os.system("systemctl daemon-reload")
os.system("systemctl enable start-ec2-vault-client.service")
