#!/bin/bash

# YellowDog Agent installer script.

# Set the Nexus username and password below or via the environment,
# to allow Agent download.
YD_NEXUS_USERNAME="${YD_NEXUS_USERNAME:-}"
YD_NEXUS_PASSWORD="${YD_NEXUS_PASSWORD:-}"

# Set "YD_INSTALL_JAVA" to anything other than "TRUE" to disable
# installing Java. The Agent startup script will expect to find
# a Java (v11+) runtime at: /usr/bin/java.
YD_INSTALL_JAVA="${YD_INSTALL_JAVA:-TRUE}"

# Set to "TRUE" for a Configured Worker Pool installation
YD_CONFIGURED_WP="${YD_CONFIGURED_WP:-FALSE}"

# Define user and directory names used by the Agent
YD_AGENT_USER="${YD_AGENT_USER:-yd-agent}"
YD_AGENT_ROOT="${YD_AGENT_ROOT:-/opt/yellowdog}"
YD_AGENT_HOME="${YD_AGENT_HOME:-/opt/yellowdog/agent}"
YD_AGENT_DATA="${YD_AGENT_DATA:-/var/opt/yellowdog/agent/data}"

################################################################################

set -euo pipefail

yd_log () {
  echo -e "*** YD" "$(date -u "+%Y-%m-%d_%H%M%S_UTC"):" "$@"
}

yd_log "Starting YellowDog Agent Setup"

if [[ "$EUID" -ne 0 ]]; then
  yd_log "Please run as root ... aborting"
  exit 1
fi

safe_grep() { grep "$@" || test $? = 1; }

################################################################################

yd_log "Checking distro using 'ID_LIKE' from '/etc/os-release'"
DISTRO=$(safe_grep "^ID_LIKE=" /etc/os-release | sed -e 's/ID_LIKE=//' \
         | sed -e 's/"//g' | awk '{print $1}')
if [[ "$DISTRO" == "" ]]; then
  yd_log "Checking distro using 'ID' from '/etc/os-release'"
  DISTRO=$(safe_grep "^ID=" /etc/os-release | sed -e 's/ID=//' \
           | sed -e 's/"//g')
fi
yd_log "Using distro = $DISTRO"

if [[ ! $(getent passwd $YD_AGENT_USER) ]]; then
  yd_log "Creating user/group: $YD_AGENT_USER"
  mkdir -p $YD_AGENT_ROOT
  case $DISTRO in
    "ubuntu" | "debian")
      adduser $YD_AGENT_USER --home $YD_AGENT_HOME --disabled-password \
              --quiet --gecos ""
      ADMIN_GRP="sudo"
      ;;
    "almalinux" | "centos" | "rhel" | "amzn" | "fedora")
      adduser $YD_AGENT_USER --home-dir $YD_AGENT_HOME
      ADMIN_GRP="wheel"
      ;;
    "sles" | "suse")
      if [[ ! $(getent group $YD_AGENT_USER) ]]; then
        groupadd $YD_AGENT_USER
      fi
      useradd $YD_AGENT_USER --home-dir $YD_AGENT_HOME --create-home \
              -g $YD_AGENT_USER
      ADMIN_GRP="wheel"
      ;;
    *)
      yd_log "Unknown distribution ... exiting"
      exit 1
      ;;
  esac
  yd_log "Creating Agent data directories / setting permissions"
  mkdir -p "$YD_AGENT_DATA/actions" "$YD_AGENT_DATA/workers"
  chown -R $YD_AGENT_USER:$YD_AGENT_USER $YD_AGENT_HOME $YD_AGENT_DATA
fi

if [[ $YD_INSTALL_JAVA == "TRUE" ]]; then
  yd_log "Installing Java"
  case $DISTRO in
    "ubuntu" | "debian")
      export DEBIAN_FRONTEND=noninteractive
      apt-get update &> /dev/null
      apt-get -y install openjdk-11-jre &> /dev/null
      ;;
    "almalinux" | "centos" | "rhel" | "amzn" | "fedora")
      yum install -y java-11 &> /dev/null
      ;;
    "sles" | "suse")
      zypper install -y java-11-openjdk &> /dev/null
      ;;
    *)
      yd_log "Unknown distribution ... exiting"
      exit 1
      ;;
  esac
  yd_log "Java installed"
fi

################################################################################

yd_log "Starting Agent download"

BASIC_AUTH=$(printf '%s:%s' "$YD_NEXUS_USERNAME" "$YD_NEXUS_PASSWORD" | base64)
curl --fail -Ls "https://nexus.yellowdog.tech/service/\
rest/v1/search/assets/download?sort=version&repository=maven-public&maven.\
groupId=co.yellowdog.platform&maven.artifactId=agent&maven.extension=jar" \
-o "$YD_AGENT_HOME/agent.jar" -H "Authorization: Basic $BASIC_AUTH"

yd_log "Agent download complete"

################################################################################

yd_log "Writing new Agent configuration file (application.yaml)"
yd_log "Inserting Task Type 'bash'"

cat > $YD_AGENT_HOME/application.yaml << EOM
yda:
  taskTypes:
    - name: "bash"
      run: "/bin/bash"
EOM

if [[ $YD_CONFIGURED_WP == "TRUE" ]]; then
  yd_log "Adding Configured Worker Pool properties"
  if [[ -z $YD_TOKEN ]]; then
    yd_log "Error: YD_TOKEN must be set"
    exit 1
  fi
  YD_INSTANCE_ID="${YD_INSTANCE_ID:-$(cat /etc/hostname)}"
  if [[ $YD_INSTANCE_ID == "" ]]; then
    YD_INSTANCE_ID="ID-$RANDOM-$RANDOM-$RANDOM"
  fi
  cat >> $YD_AGENT_HOME/application.yaml << EOM
  token: "$YD_TOKEN"
  instanceId: "$YD_INSTANCE_ID"
  provider: "ON_PREMISE"
  hostname: "${YD_HOSTNAME:-$(cat /etc/hostname)}"
  services-schema.default-url: "${YD_URL:-https://portal.yellowdog.co/api}"
  region: "${YD_REGION:-}"
  instanceType: "${YD_INSTANCE_TYPE:-}"
  sourceName: "${YD_SOURCE_NAME:-}"
  vcpus: "${YD_VCPUS:-$(nproc)}"
  ram: "${YD_RAM:-$(safe_grep MemTotal /proc/meminfo | \
           awk -v OFMT='%.2f' '{mem_gb = $2 / (1024*1024) ; print mem_gb}')}"
  workerTag: "${YD_WORKER_TAG:-}"
  privateIpAddress: "${YD_PRIVATE_IP:-}"
  publicIpAddress: "${YD_PUBLIC_IP:-}"
  createWorkers:
    targetType: "${YD_WORKER_TARGET_TYPE:-PER_NODE}"
    targetCount: "${YD_WORKER_TARGET_COUNT:-1}"
  schedule:
    enabled: "${YD_SCHEDULE_ENABLED:-false}"
    startup:
      - "${YD_SCHEDULE_ENABLED_STARTUP:-0 0 18 * * MON-FRI}"
    shutdown:
      - "${YD_SCHEDULE_ENABLED_SHUTDOWN:-0 0 7 * * MON-FRI}"
logging.pattern.console: "%d{yyyy-MM-ddHH:mm:ss,SSS} Worker[%10.10thread]\
 %-5level[%40logger{40}] %message [%class{0}:%method:%line]%n"
EOM
fi

yd_log "Agent configuration file created"

################################################################################

yd_log "Creating Agent startup script (start.sh)"
cat > $YD_AGENT_HOME/start.sh << EOM
#!/bin/sh
/usr/bin/java -jar $YD_AGENT_HOME/agent.jar
EOM

yd_log "Setting directory permissions"
chown $YD_AGENT_USER:$YD_AGENT_USER -R $YD_AGENT_HOME
chmod ug+x $YD_AGENT_HOME/start.sh

################################################################################

yd_log "Setting up the Agent systemd service"
cat > /etc/systemd/system/yd-agent.service << EOM
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

cat > /etc/systemd/system/yd-agent.service.d/yd-agent.conf << EOM
[Service]
Environment="YD_AGENT_HOME=$YD_AGENT_HOME"
Environment="YD_AGENT_DATA=$YD_AGENT_DATA"
EOM

yd_log "Systemd files created"

yd_log "Enabling & starting Agent service (yd-agent)"
systemctl enable yd-agent &> /dev/null
systemctl restart --no-block yd-agent &> /dev/null
yd_log "Agent service enabled and (re)started"

################################################################################

# Uncomment the following to give $YD_AGENT_USER passwordless sudo capability

#yd_log "Adding $YD_AGENT_USER to passwordless sudoers"
#usermod -aG $ADMIN_GRP $YD_AGENT_USER
#echo -e "$YD_AGENT_USER\tALL=(ALL)\tNOPASSWD: ALL" > \
#        /etc/sudoers.d/020-$YD_AGENT_USER

################################################################################

# Uncomment the following to add a public key for $YD_AGENT_USER

#yd_log "Adding SSH public key for user $YD_AGENT_USER"
#mkdir -p $YD_AGENT_HOME/.ssh
#chmod og-rwx $YD_AGENT_HOME/.ssh
## Insert your public key below, between the two 'EOM' entries
#cat >> $YD_AGENT_HOME/.ssh/authorized_keys << EOM
#<Insert Public Key Here>
#EOM
#chmod og-rw $YD_AGENT_HOME/.ssh/authorized_keys
#chown -R $YD_AGENT_USER:$YD_AGENT_USER $YD_AGENT_HOME/.ssh

################################################################################

yd_log "YellowDog Agent installation complete"

################################################################################
