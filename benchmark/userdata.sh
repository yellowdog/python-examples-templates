#!/bin/bash

# User Data: applied prior to the User Data in the Template

# Bash Task  ###################################################################

# Insert 'bash' Task Type into application.yaml, if not already present
grep -q '"bash"' $YD_AGENT_HOME/application.yaml
if [[ $? == 1 ]]
then
  sed -i '/^yda.taskTypes:/a\  - name: "bash"\n    run: "/bin/bash"' \
      $YD_AGENT_HOME/application.yaml
fi

# Installations  ###############################################################

apt-get update

apt-get install -y sysbench \
    build-essential \
    python3-pip python3-venv \
    libtiff5-dev libjpeg8-dev \
    libopenjp2-7-dev zlib1g-dev \
    libfreetype6-dev liblcms2-dev libwebp-dev tcl8.6-dev tk8.6-dev python3-tk \
    libharfbuzz-dev libfribidi-dev libxcb1-dev

# Give user 'yd-agent' sudo capabilities  ######################################

usermod -a -G admin yd-agent
echo -e "yd-agent\tALL=(ALL)\tNOPASSWD: ALL" > /etc/sudoers.d/020-yd-agent

################################################################################
