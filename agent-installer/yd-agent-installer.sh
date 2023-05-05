#!/bin/bash

# YellowDog Agent installer script.

# Uncomment and set the Nexus username and password below.
# These are required to download the YellowDog Agent JAR file.
# NEXUS_USERNAME="<INSERT YELLOWDOG NEXUS USERNAME HERE>"
# NEXUS_PASSWORD="<INSERT YELLOWDOG NEXUS PASSWORD HERE>"

# Set the following to anything other than "TRUE" to suppress
# Java installation. The Agent startup script will expect to find
# a Java (v11+) runtime at: /usr/bin/java.
INSTALL_JAVA="TRUE"

################################################################################

set -euo pipefail

# Logging
yd_log () {
  echo -e "*** YD" "$(date -u "+%Y-%m-%d_%H%M%S_UTC"):" "$@"
}

# Ignore non-zero exit codes from grep
safe_grep() { grep "$@" || test $? = 1; }

################################################################################

# Uncomment the section below for Configured Worker Pool installations.
#    Ensure 'YD_TOKEN', at least, is populated.

#CONFIGURED_WP="TRUE"
#
## The following can be overridden from the environment or populated directly
#YD_TOKEN="${YD_TOKEN:-}"
#YD_VCPUS="${YD_VCPUS:-$(nproc)}"
#YD_RAM="${YD_RAM:-$(safe_grep MemTotal /proc/meminfo | \
#           awk -v OFMT='%.2f' '{mem_gb = $2 / (1024*1024) ; print mem_gb}')}"
#YD_INSTANCE_ID="${YD_INSTANCE_ID:-$(cat /etc/hostname)}"
#YD_REGION="${YD_REGION:-}"
#YD_INSTANCE_TYPE="${YD_INSTANCE_TYPE:-}"
#YD_SOURCE_NAME="${YD_SOURCE_NAME:-}"
#YD_PUBLIC_IP="${YD_PUBLIC_IP:-}"
#YD_PRIVATE_IP="${YD_PRIVATE_IP:-}"
#YD_HOSTNAME="${YD_HOSTNAME:-$(cat /etc/hostname)}"
#YD_WORKER_TAG="${YD_WORKER_TAG:-}"
#YD_WORKER_COUNT="${YD_WORKER_COUNT:-$YD_VCPUS}"
#YD_URL="${YD_URL:-https://portal.yellowdog.co/api}"
#YD_LOG_STR="${YD_LOG_STR:-%d{yyyy-MM-dd HH:mm:ss,SSS} [%10.10thread] \
#%-5level %message %n}"

################################################################################

if [[ "$EUID" -ne 0 ]] ; then
  yd_log "Please run as root ... aborting"
  exit 1
fi

################################################################################

# Define required variables
YD_AGENT_USER="yd-agent"
YD_AGENT_ROOT="/opt/yellowdog"
YD_AGENT_HOME="/opt/yellowdog/agent"
YD_AGENT_DATA="/var/opt/yellowdog/agent/data"
MAVEN_REPO="maven-public"

################################################################################

yd_log "Starting YellowDog Agent Setup"

################################################################################

yd_log "Checking for existing user: $YD_AGENT_USER"
if id -u "$YD_AGENT_USER" >/dev/null 2>&1 ; then
  yd_log "User $YD_AGENT_USER already exists ... aborting script"
  exit 1
fi

################################################################################

yd_log "Checking distro using 'ID_LIKE' from '/etc/os-release'"
# Pick the first element of the 'ID_LIKE' property
DISTRO=$(safe_grep "^ID_LIKE=" /etc/os-release | sed -e 's/ID_LIKE=//' \
         | sed -e 's/"//g' | awk '{print $1}')
# If empty, use the 'ID' property
if [[ "$DISTRO" == "" ]] ; then
  yd_log "Checking distro using 'ID' from '/etc/os-release'"
  DISTRO=$(safe_grep "^ID=" /etc/os-release | sed -e 's/ID=//' \
           | sed -e 's/"//g')
fi
yd_log "Using distro = $DISTRO"

yd_log "Creating user $YD_AGENT_USER and installing Java 11"

mkdir -p $YD_AGENT_ROOT

# All distro-specific operations are encapsulated below
case $DISTRO in
  "ubuntu" | "debian")
    adduser $YD_AGENT_USER --home $YD_AGENT_HOME --disabled-password \
            --quiet --gecos ""
    if [[ $INSTALL_JAVA == "TRUE" ]]; then
      export DEBIAN_FRONTEND=noninteractive
      apt-get update &> /dev/null && \
      apt-get -y install openjdk-11-jre &> /dev/null
    fi
    ADMIN_GRP="sudo"
    ;;
  "almalinux" | "centos" | "rhel" | "amzn" | "fedora")
    adduser $YD_AGENT_USER --home-dir $YD_AGENT_HOME
    if [[ $INSTALL_JAVA == "TRUE" ]]; then
      yum install -y java-11 &> /dev/null
    fi
    ADMIN_GRP="wheel"
    ;;
  "sles" | "suse")
    groupadd $YD_AGENT_USER
    useradd $YD_AGENT_USER --home-dir $YD_AGENT_HOME --create-home \
            -g $YD_AGENT_USER
    if [[ $INSTALL_JAVA == "TRUE" ]]; then
      zypper install -y java-11-openjdk &> /dev/null
    fi
    ADMIN_GRP="wheel"
    ;;
  *)
    yd_log "Unknown distribution ... exiting"
    exit 1
    ;;
esac

yd_log "User $YD_AGENT_USER created and Java installed"

yd_log "Creating Agent data directories / setting permissions"
mkdir -p "$YD_AGENT_DATA/actions" "$YD_AGENT_DATA/workers"
chown -R $YD_AGENT_USER:$YD_AGENT_USER $YD_AGENT_HOME $YD_AGENT_DATA

################################################################################

yd_log "Starting Agent download"

BASIC_AUTH=$(printf '%s:%s' "$NEXUS_USERNAME" "$NEXUS_PASSWORD" | base64)
curl --fail -Ls "https://nexus.yellowdog.tech/service/\
rest/v1/search/assets/download?sort=version&repository=$MAVEN_REPO&maven.\
groupId=co.yellowdog.platform&maven.artifactId=agent&maven.extension=jar" \
-o "$YD_AGENT_HOME/agent.jar" -H "Authorization: Basic $BASIC_AUTH"

yd_log "Agent download complete"

################################################################################

yd_log "Writing Agent configuration file (application.yaml)"
yd_log "Inserting Task Type 'bash'"

cat > $YD_AGENT_HOME/application.yaml <<- EOM
yda:
  taskTypes:
    - name: "bash"
      run: "/bin/bash"
EOM

CONFIGURED_WP="${CONFIGURED_WP:-FALSE}"
if [[ $CONFIGURED_WP == "TRUE" ]]; then
  yd_log "Adding Configured Worker Pool properties"
  cat >> $YD_AGENT_HOME/application.yaml << EOM
  provider: "ON_PREMISE"
  instanceId: "$YD_INSTANCE_ID"
  hostname: "$YD_HOSTNAME"
  token: "$YD_TOKEN"
  services-schema.default-url: "$YD_URL"
  region: "$YD_REGION"
  instanceType: "$YD_INSTANCE_TYPE"
  sourceName: "$YD_SOURCE_NAME"
  vcpus: $YD_VCPUS
  ram: $YD_RAM
  workerTag: "$YD_WORKER_TAG"
  privateIpAddress: "$YD_PRIVATE_IP"
  publicIpAddress: "$YD_PUBLIC_IP"
  createWorkers:
    targetType: "PER_NODE"
    targetCount: $YD_WORKER_COUNT
  logging.pattern.console: "$YD_LOG_STR"
EOM
fi

yd_log "Agent configuration file created"

################################################################################

yd_log "Creating Agent startup script (start.sh)"
cat > $YD_AGENT_HOME/start.sh <<- EOM
#!/bin/sh
/usr/bin/java -jar $YD_AGENT_HOME/agent.jar
EOM

yd_log "Setting directory permissions"
chown $YD_AGENT_USER:$YD_AGENT_USER -R $YD_AGENT_HOME
chmod ug+x $YD_AGENT_HOME/start.sh

################################################################################

yd_log "Setting up the Agent systemd service"
cat > /etc/systemd/system/yd-agent.service <<- EOM
[Unit]
Description=YellowDog Agent
After=cloud-final.service

[Service]
User=$YD_AGENT_USER
WorkingDirectory=$YD_AGENT_HOME
ExecStart=$YD_AGENT_HOME/start.sh
SuccessExitStatus=143
TimeoutStopSec=10
Restart=on-failure
RestartSec=5
LimitMEMLOCK=8388608

[Install]
WantedBy=cloud-init.target
EOM

mkdir -p /etc/systemd/system/yd-agent.service.d

cat > /etc/systemd/system/yd-agent.service.d/yd-agent.conf <<- EOM
[Service]
Environment="YD_AGENT_HOME=$YD_AGENT_HOME"
Environment="YD_AGENT_DATA=$YD_AGENT_DATA"
EOM

yd_log "Systemd files created"

yd_log "Enabling & starting Agent service (yd-agent)"
systemctl enable yd-agent &> /dev/null
systemctl start --no-block yd-agent &> /dev/null
yd_log "Agent service enabled and started"

################################################################################

# Uncomment the following to give $YD_AGENT_USER passwordless sudo capability

#yd_log "Adding $YD_AGENT_USER to passwordless sudoers"
#usermod -aG $ADMIN_GRP $YD_AGENT_USER
#echo -e "$YD_AGENT_USER\tALL=(ALL)\tNOPASSWD: ALL" > \
#        /etc/sudoers.d/020-$YD_AGENT_USER

################################################################################

# Uncomment the following to add a public key for $YD_AGENT_USER

#yd_log "Adding SSH public key for user $YD_AGENT_USER"
#
#mkdir -p $YD_AGENT_HOME/.ssh
#chmod og-rwx $YD_AGENT_HOME/.ssh
#
## Insert your public key below, between the two 'EOM' entries
#cat >> $YD_AGENT_HOME/.ssh/authorized_keys << EOM
#<Insert Public Key Here>
#EOM
#
#chmod og-rw $YD_AGENT_HOME/.ssh/authorized_keys
#chown -R $YD_AGENT_USER:$YD_AGENT_USER $YD_AGENT_HOME/.ssh

################################################################################

yd_log "YellowDog Agent installation complete"

################################################################################
