#!/usr/bin/python
'''
 __________________________________________________________________________________________
| About   : This sets up the required CloudWatchLogs Environment configuration on AWS EC2  |
| Author  : Arun Jayanth,  H&W Team, ?????                                               |
| Purpose : To Be used along with ?????'s Packer AMI Builder Script                      |
 __________________________________________________________________________________________
|                       REQUIRED INPUT VARIABLES                                           |
 ------------------------------------------------------------------------------------------|
| REGION            = Region which the CloudWatch Logs Export.Defaults to eu-west-2        |
| OS_LOGS           = Comma separated OS Log Paths to Export.                              |
| CONTAINER_LOGS    = Comma separated Container Console Log Paths to Export                |
| AUDIT_LOGS        = Comma separated Audit Log Paths to Export                            |
| APP_LOGS          = Comma separated App Log Paths to Export                              |
| * Format of *_LOGS should be LOG_PATH1:STREAM_NAME1,LOG_PATH2:STREAM_NAME2               |
 __________________________________________________________________________________________
|                       DEFAULTTED LOG group                                               |
 ------------------------------------------------------------------------------------------
| If no project or environment is found in the Log groups will be defaulted to             |
| * ?????/no_tags/SystemOSLogs,                                                          |
| * ?????/no_tags/ContainerConsoleLogs,                                                  |
| * ?????/no_tags/AppLogs,                                                               |
| * ?????/no_tags/AuditLogs                                                              |
 __________________________________________________________________________________________
 __________________________________________________________________________________________
|                              OUTPUT FILES                                                |
 ------------------------------------------------------------------------------------------
| These output files will be generated from this script in EC2. It can be used             |
| as EnvironmentFile in systemd file to get the awslogs group parameter                    |
| * /etc/cloudwatchlogs.config with the following parameters                               |
|   - export OS_LOGGROUP = <PROJECT>/<ENVIRONMENT>/SystemOSLogs                            |
|   - export CONTAINER_LOGGROUP = <PROJECT>/<ENVIRONMENT>/ContainerConsoleLogs             |
|   - export APP_LOGGROUP = <PROJECT>/<ENVIRONMENT>/AppLogs                                |
|   - export AUDIT_LOGGROUP = <PROJECT>/<ENVIRONMENT>/AuditLogs                            |
|   - export CW_NAMESPACE = <PROJECT>/<ENVIRONMENT>/CWAgent                                |
|   - export OS_LOGS = <OS_LOGS>                                                           |
|   - export CONTAINER_LOGS = <CONTAINER_LOGS>                                             |
|   - export AUDIT_LOGS = <AUDIT_LOGS>                                                     |
|   - export APP_LOGS = <APP_LOGS>                                                         |
 __________________________________________________________________________________________
'''
import os,logging

logging.basicConfig()
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)
try:
    REGION = os.environ["REGION"]
except:
    REGION = "eu-west-2"

'''
There are 2 parts to this script.
* First is to make sure we have the environment variables and it starts up on boot
* Second is to Install the Cloudwatch Agent to extra the logs out of the box.
'''

'''
This is Part 1 : Setting up the Environment File
'''

logger.debug("INFO: Writing the CloudWatch Logs Environment File")

# Create the CloudWatch Environment Template File to be created
CloudWatchEnvFileTmpl="""OS_LOGGROUP=PROJECT/ENVIRONMENT/SystemOSLogs
CONTAINER_LOGGROUP=PROJECT/ENVIRONMENT/ContainerConsoleLogs
APP_LOGGROUP=PROJECT/ENVIRONMENT/AppLogs
AUDIT_LOGGROUP=PROJECT/ENVIRONMENT/AuditLogs
CW_NAMESPACE=PROJECT/ENVIRONMENT/CWAgent
OS_LOGS=OS_LOGS_FROM_PACKER_BUILD
CONTAINER_LOGS=CONTAINER_LOGS_FROM_PACKER_BUILD
AUDIT_LOGS=AUDIT_LOGS_FROM_PACKER_BUILD
APP_LOGS=APP_LOGS_FROM_PACKER_BUILD
"""
try:
    OS_LOGS_FROM_PACKER_BUILD = os.environ["OS_LOGS"]
except:
    OS_LOGS_FROM_PACKER_BUILD = "none"

try:
    CONTAINER_LOGS_FROM_PACKER_BUILD = os.environ["CONTAINER_LOGS"]
except:
    CONTAINER_LOGS_FROM_PACKER_BUILD = "none"

try:
    APP_LOGS_FROM_PACKER_BUILD = os.environ["APP_LOGS"]
except:
    APP_LOGS_FROM_PACKER_BUILD = "none"

try:
    AUDIT_LOGS_FROM_PACKER_BUILD = os.environ["AUDIT_LOGS"]
except:
    AUDIT_LOGS_FROM_PACKER_BUILD = "none"

CloudWatchEnvFileTmpl = CloudWatchEnvFileTmpl.replace("OS_LOGS_FROM_PACKER_BUILD",OS_LOGS_FROM_PACKER_BUILD)
CloudWatchEnvFileTmpl = CloudWatchEnvFileTmpl.replace("APP_LOGS_FROM_PACKER_BUILD",APP_LOGS_FROM_PACKER_BUILD)
CloudWatchEnvFileTmpl = CloudWatchEnvFileTmpl.replace("CONTAINER_LOGS_FROM_PACKER_BUILD",CONTAINER_LOGS_FROM_PACKER_BUILD)
CloudWatchEnvFileTmpl = CloudWatchEnvFileTmpl.replace("AUDIT_LOGS_FROM_PACKER_BUILD",AUDIT_LOGS_FROM_PACKER_BUILD)

with open("/etc/cloudwatchlogs.config.tmpl","w") as CloudWatchEnvFile:
    CloudWatchEnvFile.write(CloudWatchEnvFileTmpl)


# Put the script for Systemd file
env_file_setup_script = """#!/usr/bin/python
import os,boto3,logging
logging.basicConfig()
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)
ec2_client = boto3.client('ec2',region_name="REGION")
instance_id = os.popen('curl http://169.254.169.254/latest/meta-data/instance-id/').read()
response = ec2_client.describe_instances(
    InstanceIds = [
        instance_id
    ]
)
tags = response['Reservations'][0]['Instances'][0]['Tags']
count = 0
value_count = 0
logger.info("INFO: Setting the PROJECT to `?????` and ENVIRONMENT to `no_tags` as default")
PROJECT = "?????"
ENVIRONMENT = "no_tags"
while count < len(tags):
    if tags[count]['Key'] == "Project" or tags[count]['Key'] == "PROJECT":
        PROJECT = tags[count]['Value']
        value_count += 1
    elif tags[count]['Key'] == "Environment" or tags[count]['Key'] == "ENVIRONMENT":
        ENVIRONMENT = tags[count]['Value']
        value_count += 1

    if value_count == 2:
        break
    else:
        count += 1
logger.info("INFO: PROJECT is set to " + PROJECT + " and ENVIRONMENT is set to " + ENVIRONMENT)
logger.debug("DEBUG: Reading the CloudWatchLogs Environment Template file /etc/cloudwatchlogs.config.tmpl")
with open ("/etc/cloudwatchlogs.config.tmpl","r") as CloudWatchEnvFileTmpl:
    TemplateData = CloudWatchEnvFileTmpl.read()

logger.debug("DEBUG: Replacing PROJECT with " + PROJECT + " and ENVIRONMENT with " + ENVIRONMENT)
TemplateData = TemplateData.replace("PROJECT",PROJECT)
TemplateData = TemplateData.replace("ENVIRONMENT",ENVIRONMENT)

with open ("/etc/cloudwatchlogs.config","w") as CloudWatchEnvFile:
    CloudWatchEnvFile.write(TemplateData)

logger.debug("DEBUG: Changing the file permissions to 755")
os.system("chmod 755 /etc/cloudwatchlogs.config")

if os.path.isfile("/etc/cloudwatchlogs.config"):
    os.system("python /etc/cron.hourly/cloudwatch-agent-setup.py")
    exit(0)
else:
    exit(1)
"""
env_file_setup_script = env_file_setup_script.replace("REGION",REGION)

with open("/etc/cloudwatchlogs-env-file-setup.py","w") as CloudWatchLogsEnvSetupFile:
    CloudWatchLogsEnvSetupFile.write(env_file_setup_script)

systemd = """[Unit]
Description=CloudWatch Logs Environment File Setup

[Service]
TimeoutStartSec=0
Restart=on-failure
RemainAfterExit=yes
RestartSec=5
ExecStartPre=/bin/sleep 30
ExecStart=-/usr/bin/python /etc/cloudwatchlogs-env-file-setup.py
ExecStop=-/usr/bin/rm /etc/cloudwatchlogs.config
SuccessExitStatus=0

[Install]
WantedBy=multi-user.target
"""
with open("/etc/systemd/system/cloudwatchlogs-env-file-setup.service","w") as SystemdFile:
    SystemdFile.write(systemd)
os.system("systemctl enable cloudwatchlogs-env-file-setup.service")

'''
Part 1 Ends Here
'''

'''
Part 2 Starts Here
 ______________________________________________________________________________
|                      HOW IT WORKS                                            |
| This setups a Systemd Service with a timer which runs as per the specified   |
| timer. It Combines the *_LOGS variables from Packer Builder and SSM Parameter|
| store path as mentioned in SSM_CLOUDAGENT_PATH and restarts the agent if it  |
| changes. For example, if any changes are made to the SSM Parameter Path at   |
| say 15 minutes past , the cloudwatch logs agent will restart at the hour     |
| and the changes will be effective from that time.                            |
| Even the METRIC_INTERVAL TAG can be changed.                                 |
 ______________________________________________________________________________
'''
logger.info("INFO: Installing the CloudWatch Agent")
os.system("curl -L https://s3.amazonaws.com/amazoncloudwatch-agent/centos/amd64/latest/amazon-cloudwatch-agent.rpm -o /tmp/amazon-cloudwatch-agent.rpm")
os.system("rpm -U /tmp/amazon-cloudwatch-agent.rpm")
os.system("rm /tmp/amazon-cloudwatch-agent.rpm")

cloudwatchagent_script="""#!/usr/bin/python
import os,logging,json,boto3

logging.basicConfig()
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

logger.info("INFO: Setting the Environment Variables from /etc/cloudwatchlogs.config")
try:
    with open ("/etc/cloudwatchlogs.config","r") as envfile:
        line = envfile.readline()
        while line:
            lineparams = line.strip()
            part1 = lineparams.split("=")[0]
            part2 = lineparams.split("=")[1]
            os.environ[part1] = part2
            line = envfile.readline()
except:
    logger.debug("INFO: /etc/cloudwatchlogs.config does not exist. Will try again next Hour")
    exit(1)
os.system("source /etc/cloudwatchlogs.config")
logger.debug("DEBUG: Getting the Environment Variables for /etc/cloudwatchlogs.config")
CW_NAMESPACE = os.environ["CW_NAMESPACE"]
OS_LOGGROUP = os.environ["OS_LOGGROUP"]
APP_LOGGROUP = os.environ["APP_LOGGROUP"]
AUDIT_LOGGROUP = os.environ["AUDIT_LOGGROUP"]
CONTAINER_LOGGROUP = os.environ["CONTAINER_LOGGROUP"]
OS_LOGS = os.environ["OS_LOGS"]
AUDIT_LOGS = os.environ["AUDIT_LOGS"]
APP_LOGS = os.environ["APP_LOGS"]
CONTAINER_LOGS = os.environ["CONTAINER_LOGS"]

logger.debug("DEBUG: Getting the Tag Information of SSM_CLOUDAGENT_PATH")
ec2_client = boto3.client('ec2',region_name="REGION")
instance_id = os.popen('curl http://169.254.169.254/latest/meta-data/instance-id/').read()
response = ec2_client.describe_instances(
    InstanceIds = [
        instance_id
    ]
)
tags = response['Reservations'][0]['Instances'][0]['Tags']
count = 0
value_count = 0
logger.info("INFO: Setting SSM_CLOUDAGENT_PATH to none as default")
SSM_CLOUDAGENT_PATH = "none"
while count < len(tags):
    if tags[count]['Key'] == "SSM_CLOUDAGENT_PATH":
        SSM_CLOUDAGENT_PATH = tags[count]['Value']
        value_count += 1

    if value_count == 1:
        break
    else:
        count += 1
logger.info("INFO:SSM_CLOUDAGENT_PATH is set to " + SSM_CLOUDAGENT_PATH)
if SSM_CLOUDAGENT_PATH != "none":
    ssm_client = boto3.client('ssm',region_name="REGION")
    Parameter = ssm_client.get_parameter(Name=SSM_CLOUDAGENT_PATH)
    with open("/tmp/CWAgentCustomFile","w") as CustomLogs:
        CustomLogs.write(Parameter['Parameter']['Value'])
    with open ("/tmp/CWAgentCustomFile","r") as customagentfile:
        line = customagentfile.readline()
        while line:
            lineparams = line.strip()
            try:
              part1 = lineparams.split("=")[0]
            except:
              line = customagentfile.readline()
              continue
            part2 = lineparams.split("=")[1]
            os.environ[part1] = part2
            line = customagentfile.readline()
    os.system("rm /tmp/CWAgentCustomFile")
    version = Parameter['Parameter']['Version']
    METRIC_INTERVAL = int(os.environ['METRIC_INTERVAL'])
    CUSTOM_OS_LOGS = os.environ['CUSTOM_OS_LOGS']
    CUSTOM_APP_LOGS = os.environ['CUSTOM_APP_LOGS']
    CUSTOM_AUDIT_LOGS = os.environ['CUSTOM_AUDIT_LOGS']
    CUSTOM_CONTAINER_LOGS = os.environ['CUSTOM_CONTAINER_LOGS']
else:
    version = 0
    METRIC_INTERVAL = 60
    CUSTOM_AUDIT_LOGS = "none"
    CUSTOM_OS_LOGS = "none"
    CUSTOM_APP_LOGS = "none"
    CUSTOM_CONTAINER_LOGS = "none"

if METRIC_INTERVAL <= 10:
    METRIC_STATS_INTERVAL = 1
else:
    METRIC_STATS_INTERVAL = 10

TO_BE_CHANGED_TO = "/opt/aws/amazon-cloudwatch-agent/bin/config" + str(version) + ".json"

def logs_json_construct(LOGSPARAM,LOGGROUP):
    return_list = []
    for i in LOGSPARAM.split(","):
        file_path = i.split(":")[0]
        logstream = "{local_hostname}-" + i.split(":")[1]
        return_list.append(
        {
          "file_path": file_path,
          "log_group_name": LOGGROUP,
          "log_stream_name": logstream,
          "timezone": "UTC"
        }
        )
    return return_list

if not os.path.isfile(TO_BE_CHANGED_TO):
    if version == 0:
        logger.info("INFO: This is the first setup of CloudWatch Agent Configuration File")
    else:
        logger.info("INFO: There is an update to CloudWatch Agent Configuration File")

    logger.debug("DEBUG: Making Log Section JSON")
    if OS_LOGS == "none" and APP_LOGS == "none" and AUDIT_LOGS == "none" and CONTAINER_LOGS == "none" and CUSTOM_OS_LOGS == "none" and CUSTOM_APP_LOGS == "none" and CUSTOM_AUDIT_LOGS == "none" and CUSTOM_CONTAINER_LOGS == "none":
        logger.info("There are no AMI Logs and Custom Logs Section")
        logs_json = {}
    else:
        logs_json = {}
        collect_list = []
        logger.debug("DEBUG: Construct OS Logs Collection")
        if OS_LOGS != "none":
            collect_list.append(logs_json_construct(OS_LOGS,OS_LOGGROUP))
        if CUSTOM_OS_LOGS != "none":
            collect_list.append(logs_json_construct(CUSTOM_OS_LOGS,OS_LOGGROUP))
        if AUDIT_LOGS != "none":
            collect_list.append(logs_json_construct(AUDIT_LOGS,AUDIT_LOGGROUP))
        if CUSTOM_AUDIT_LOGS != "none":
            collect_list.append(logs_json_construct(CUSTOM_AUDIT_LOGS,AUDIT_LOGGROUP))
        if APP_LOGS != "none":
            collect_list.append(logs_json_construct(APP_LOGS,APP_LOGGROUP))
        if CUSTOM_APP_LOGS != "none":
            collect_list.append(logs_json_construct(CUSTOM_APP_LOGS,APP_LOGGROUP))
        if CONTAINER_LOGS != "none":
            collect_list.append(logs_json_construct(CONTAINER_LOGS,CONTAINER_LOGGROUP))
        if CUSTOM_CONTAINER_LOGS != "none":
            collect_list.append(logs_json_construct(CUSTOM_CONTAINER_LOGS,CONTAINER_LOGGROUP))

        flatten_collect_list = []
        for sublist in collect_list:
            for item in sublist:
                flatten_collect_list.append(item)

        logs_json = {
        "logs": {
            "logs_collected": {
                "files": {
                    "collect_list" : flatten_collect_list
                }
            }
        }
        }

    logger.debug("DEBUG: Setting the Agent Section JSON and Metrics Section JSON")
    agent_json = {
    "agent": {
            "metrics_collection_interval": METRIC_INTERVAL,
            "region":  "REGION",
            "logfile": "",
            "debug": False
    }
    }

    metrics_json = {
    "metrics": {
        "namespace":  CW_NAMESPACE ,
        "append_dimensions": {
            "AutoScalingGroupName": "${aws:AutoScalingGroupName}",
            "InstanceId": "${aws:InstanceId}",
            "InstanceType": "${aws:InstanceType}"
        },
        "metrics_collected": {
            "cpu": {
                "measurement": [
                  "cpu_time_active",
                  "cpu_time_guest",
                  "cpu_time_guest_nice",
                  "cpu_time_idle",
                  "cpu_time_iowait",
                  "cpu_time_irq",
                  "cpu_time_nice",
                  "cpu_time_softirq",
                  "cpu_time_steal",
                  "cpu_time_system",
                  "cpu_time_user",
                  "cpu_usage_active",
                  "cpu_usage_guest",
                  "cpu_usage_guest_nice",
                  "cpu_usage_idle",
                  "cpu_usage_iowait",
                  "cpu_usage_irq",
                  "cpu_usage_nice",
                  "cpu_usage_softirq",
                  "cpu_usage_steal",
                  "cpu_usage_system",
                  "cpu_usage_user"
                ],
                "metrics_collection_interval": METRIC_INTERVAL,
                "resources": [
                    "*"
                ],
                "totalcpu": False
            },
            "disk": {
                "measurement": [
                  "free",
                  "total",
                  "used",
                  "used_percent",
                  "inodes_free",
                  "inodes_used",
                  "inodes_total"
                 ],
                "metrics_collection_interval": METRIC_INTERVAL,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "read_time",
                    "write_time",
                    "iops_in_progress",
                    "io_time",
                    "write_bytes",
                    "read_bytes",
                    "writes",
                    "reads"
                ],
                "metrics_collection_interval": METRIC_INTERVAL,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_active",
                    "mem_available",
                    "mem_available_percent",
                    "mem_buffered",
                    "mem_cached",
                    "mem_free",
                    "mem_inactive",
                    "mem_total",
                    "mem_used",
                    "mem_used_percent"
                ],
                "metrics_collection_interval": METRIC_INTERVAL
            },
            "net": {
                "measurement": [
                  "bytes_sent",
                  "bytes_recv",
                  "drop_in",
                  "drop_out",
                  "err_in",
                  "err_out",
                  "packets_sent",
                  "packets_recv"
                ],
                "resources": [
                  "*"
                ],
                "metrics_collection_interval": METRIC_INTERVAL
              },
            "netstat": {
                "measurement": [
                    "tcp_close",
                    "tcp_close_wait",
                    "tcp_closing",
                    "tcp_established",
                    "tcp_fin_wait1",
                    "tcp_fin_wait2",
                    "tcp_last_ack",
                    "tcp_listen",
                    "tcp_none",
                    "tcp_syn_sent",
                    "tcp_syn_recv",
                    "tcp_time_wait",
                    "udp_socket"
                ],
                "metrics_collection_interval": METRIC_INTERVAL
            },
          "processes": {
            "measurement": [
              "paging",
              "idle",
              "blocked",
              "dead",
              "running",
              "sleeping",
              "stopped",
              "total",
              "total_threads",
              "wait",
              "zombies"
            ]
          },
        "statsd": {
            "metrics_aggregation_interval": METRIC_INTERVAL,
            "metrics_collection_interval": METRIC_STATS_INTERVAL,
            "service_address": ":8125"
          },
        "swap": {
                "measurement": [
                  "swap_free",
                  "swap_used",
                  "swap_used_percent"
                ],
                "metrics_collection_interval": METRIC_INTERVAL
            }
        }
    }
    }

    merge_json = {key: value for (key, value) in (agent_json.items() + metrics_json.items() + logs_json.items())}

    with open (TO_BE_CHANGED_TO,"w") as CloudWatchAgentFile:
        CloudWatchAgentFile.write(json.dumps(merge_json,indent=4))

    os.system("/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:" + TO_BE_CHANGED_TO + " -s")
"""
cloudwatchagent_script = cloudwatchagent_script.replace("REGION",REGION)

with open("/etc/cron.hourly/cloudwatch-agent-setup.py","w") as CloudWatchAgentSetupFile:
    CloudWatchAgentSetupFile.write(cloudwatchagent_script)

os.system("chmod 755 /etc/cron.hourly/cloudwatch-agent-setup.py")
