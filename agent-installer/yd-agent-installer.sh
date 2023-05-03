#!/bin/bash

# YellowDog Agent installer script. This script will:
#   1. Create a user 'yd-agent' and its supporting directories
#   2. Install Java 11 (this step can be omitted)
#   3. Download and configure the YellowDog Agent JAR file
#   4. Create the Agent's configuration file and startup script
#   5. Set up the YellowDog Agent to run as a systemd service
#   6. Optionally add 'yd-agent' to passwordless sudoers
#   7. Optionally add a public SSH key for 'yd-agent'

# Tested on:
#   - Ubuntu 22.04
#   - AlmaLinux 9.1
#   - Amazon Linux 2
#   - Debian 11
#   - CentOS Stream 8 & 9
#   - Red Hat Enterprise Linux 9.1
#   - SUSE (SLES 15 SP4)

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

# Logging function
yd_log () {
  echo -e "*** YD" "$(date -u "+%Y-%m-%d_%H%M%S_UTC"):" "$@"
}

################################################################################

# Ensure we're running as root
if [[ "$EUID" -ne 0 ]]
  then yd_log "Please run as root ... aborting"
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

yd_log "Checking for already created user: $YD_AGENT_USER"
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
    if [[ $INSTALL_JAVA == "TRUE" ]]; then
      export DEBIAN_FRONTEND=noninteractive
      apt-get update &> /dev/null && \
      apt-get -y install openjdk-11-jre &> /dev/null
    fi
    ADMIN_GRP="sudo"
    ;;
  "almalinux" | "centos" | "rhel" | "amzn")
    adduser $YD_AGENT_USER --home-dir $YD_AGENT_HOME
    if [[ $INSTALL_JAVA == "TRUE" ]]; then
      yum install -y java-11 &> /dev/null
    fi
    ADMIN_GRP="wheel"
    ;;
  "sles")
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

yd_log "Creating Agent data directories and setting directory permissions"
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
#ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDBAwA8lQurxJh2m9zyB6A/QG7/0jRYQQgH0zJg\
#Tr8+uGdYJs4hpbsU43jqfdiOY9gBN35j2LFfHHsYxJmFkFXh2DQn3+WZhzxYzPOiSIBtNnHmRY3j\
#71wJbNUX1kF4VyifiaiuPviJd0YKD/y0UnhZKBs4EQQB9qPzpcSoixcLa6hgh5gqY8yA+BuI4dgK\
#5SG2t5seujJ45bT67HvCeFYShFXPsvB9KwhptBF1Hd961+AoXO8IVXSEKBnrTTecbeFgc0V2vRqO\
#TNdSiWrD71mij3NUd3dzp+9qepDZaNtNXMJ8jnF2nzk43JvrRzteWJlyya+63/bvdq/jj7jLH3tN\
#pcyNw16YmctpjKr7uKc4k6gEa3b7YaELwX8g1xGQib95RXuzvef7qduDAbQbvadbvM97iohaeWMM\
#7uh1rNM6qsVdyGd1FUVNFiPUqsQ5sQhRdnryu/lF10hDArGkhu+tmwQEFsp2ymFlaVexKWB/Q20q\
#A0bE4yNXbZF4WUdBJzc= pwt@pwt-mbp-14.local
#EOM
#
#chmod og-rw $YD_AGENT_HOME/.ssh/authorized_keys
#chown -R $YD_AGENT_USER:$YD_AGENT_USER $YD_AGENT_HOME/.ssh

################################################################################

yd_log "YellowDog Agent installation complete"

################################################################################
