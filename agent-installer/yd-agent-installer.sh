#!/bin/bash

# YellowDog Agent installer script. This script will:
#   1. Create a user 'yd-agent' and its supporting directories
#   2. Install Java 11 (this step can be suppressed)
#   3. Download and configure the YellowDog Agent JAR file
#   4. Set up yd-agent as a systemd service

# Tested on:
#   - Ubuntu 22.04
#   - AlmaLinux 9.1
#   - Amazon Linux 2
#   - Debian 11
#   - CentOS Stream 8 & 9
#   - Red Hat Enterprise Linux 9.1

# Set the Nexus username and password below.
# These are required to download the YellowDog Agent.
NEXUS_USERNAME="<INSERT YELLOWDOG NEXUS USERNAME HERE>"
NEXUS_PASSWORD="<INSERT YELLOWDOG NEXUS PASSWORD HERE>"

# Set the following to anything other than "TRUE" to suppress
# Java installation. The Agent start script will expect to find
# the Java runtime at: /usr/bin/java.
INSTALL_JAVA="TRUE"

################################################################################

# Ensure we're running as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

set -u -o pipefail

################################################################################

# Define required variables
YD_AGENT_USER="yd-agent"
YD_AGENT_ROOT="/opt/yellowdog"
YD_AGENT_HOME="/opt/yellowdog/agent"
YD_AGENT_DATA="/var/opt/yellowdog/agent/data"
MAVEN_REPO="maven-public"

################################################################################

# Logging function
yd_log () {
  echo -e "*** YD" "$(date -u "+%Y-%m-%d_%H%M%S_UTC"):" "$@"
}

################################################################################

yd_log "Starting YellowDog Agent Setup"

################################################################################

yd_log "Checking for already created user"
if id -u "$YD_AGENT_USER" >/dev/null 2>&1
then
  yd_log "User $YD_AGENT_USER already exists ... aborting script"
  exit 1
fi

################################################################################

yd_log "Checking Linux distribution using 'ID' from '/etc/os-release'"
DISTRO=$(grep ^ID= /etc/os-release | sed -e 's/ID=//' | sed -e 's/"//g')
yd_log "Distro ID discovered as: $DISTRO"

yd_log "Distro-specific steps: creating user $YD_AGENT_USER \
and installing Java 11"

mkdir -p $YD_AGENT_ROOT

# All distro-specific operations are encapsulated below
case $DISTRO in
  "ubuntu" | "debian")
    adduser $YD_AGENT_USER --home $YD_AGENT_HOME --disabled-password \
      --quiet --gecos ""
    if [ $INSTALL_JAVA == "TRUE" ]; then
      apt-get update > /dev/null && \
      apt-get -y install openjdk-11-jre > /dev/null
    fi
    ;;
  "almalinux" | "centos" | "rhel")
    adduser $YD_AGENT_USER --home-dir $YD_AGENT_HOME
    if [ $INSTALL_JAVA == "TRUE" ]; then
      yum install -y java-11-openjdk > /dev/null
    fi
    ;;
  "amzn")
    adduser $YD_AGENT_USER --home-dir $YD_AGENT_HOME
    if [ $INSTALL_JAVA == "TRUE" ]; then
      yum install -y java-11 > /dev/null
    fi
    ;;
  *)
    yd_log "Unknown distribution ... exiting"
    exit 1
    ;;
esac

yd_log "User $YD_AGENT_USER created and Java installed"

yd_log "Creating Agent data directories and setting directory permissions"
mkdir -p "$YD_AGENT_DATA/actions" "$YD_AGENT_DATA/workers"
chown -R $YD_AGENT_USER:$YD_AGENT_USER $YD_AGENT_HOME $YD_AGENT_DATA

################################################################################

yd_log "Populating Nexus credentials"
cat > /root/.netrc << EOF
machine nexus.yellowdog.tech
    login $NEXUS_USERNAME
    password $NEXUS_PASSWORD
EOF

yd_log "Starting Agent download"

curl --fail \
-Lsno "$YD_AGENT_HOME/agent.jar" "http://nexus.yellowdog.tech/service/\
rest/v1/search/assets/download?sort=version&repository=$MAVEN_REPO&maven.\
groupId=co.yellowdog.platform&maven.artifactId=agent&maven.extension=jar"
CURL_EXIT="$?"

yd_log "Removing Nexus credentials"
rm -f /root/.netrc

# Check for successful Agent download
if [[ $CURL_EXIT -ne 0 ]]
then
  yd_log "Agent download failed ... aborting script"
  exit 1
else
  yd_log "Agent download complete"
fi

################################################################################

yd_log "Writing Agent configuration file (application.yaml)"
yd_log "Inserting Task Type 'bash'"

cat > $YD_AGENT_HOME/application.yaml <<- EOM
yda.taskTypes:
  - name: "bash"
    run: "/bin/bash"
EOM

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

yd_log "Enabling Agent service (yd-agent)"
systemctl enable yd-agent && systemctl start --no-block yd-agent

yd_log "Agent service enabled and started"

################################################################################

yd_log "YellowDog Agent installation complete"

################################################################################
