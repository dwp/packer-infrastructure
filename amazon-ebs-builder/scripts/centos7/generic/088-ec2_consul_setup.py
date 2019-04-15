#!/usr/bin/python
'''
 ____________________________________________________________________________
| About   : This sets up the required Consul Installation on AWS EC2         |
| Author  : Arun Jayanth,  H&W Team, Burbank                                 |
| Purpose : To Be used along with Burbank's Packer AMI Builder Script        |
 ____________________________________________________________________________
|                       REQUIRED INPUT VARIABLES                             |
 ----------------------------------------------------------------------------
| REGION            = Region which the ECR image will be taken from.         |
| CONSUL_VERSION     = Version of Consul to use. Binds with Each AMI         |
| CONSUL_LICENSE     = License of Consul . opensource or enterprise          |
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
CONSUL_VERSION = os.environ['CONSUL_VERSION']
CONSUL_LICENSE = os.environ['CONSUL_LICENSE']
OWNER = os.environ['OWNER']
HASHICORP_GPG_KEY = os.environ['HASHICORP_GPG_KEY']

# Download the GPG Key from GPG Server
for server in ["hkp://p80.pool.sks-keyservers.net:80","hkp://keyserver.ubuntu.com:80","hkp://pgp.mit.edu:80"]:
    response = os.popen("gpg --keyserver "+ server + " --recv-keys " + HASHICORP_GPG_KEY)
    exit_status = response.close()
    if str(exit_status) == "None":
        break

# Install the Vault Agent
if CONSUL_LICENSE == "enterprise":
    download_link_prefix = "https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/consul/ent/" + CONSUL_VERSION + "/consul-enterprise_" + CONSUL_VERSION + "%2Bent_"
elif CONSUL_LICENSE == "opensource":
    download_link_prefix = "https://releases.hashicorp.com/consul/" + CONSUL_VERSION + "/consul_" + CONSUL_VERSION + "_"

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
os.system("chmod 755 /usr/local/bin/consul")
files_to_remove = ["linux_amd64.zip","SHA256SUMS","SHA256SUMS.sig"]
for to_remove in files_to_remove:
    print ("Removing file: " + to_remove)
    os.system("rm /tmp/"+ to_remove)
