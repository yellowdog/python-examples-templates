#!/bin/bash

# Instance user data: run by cloud-init every time an instance boots.
# This script runs as root.

# Bash Task Type  ##############################################################

# This ensures that the (Linux) instance can run 'bash' Tasks by inserting a
# 'bash' Task Type into the Agent's configuration file (if required).

# Insert 'bash' Task Type into 'application.yaml', if not already present
grep -q '"bash"' $YD_AGENT_HOME/application.yaml
if [[ $? == 1 ]]
then
  sed -i '/^yda.taskTypes:/a\  - name: "bash"\n    run: "/bin/bash"' \
      $YD_AGENT_HOME/application.yaml
fi

# End  #########################################################################
