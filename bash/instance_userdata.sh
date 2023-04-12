#!/bin/bash

# User Data: applied on instance boot, prior to any user data in the Template.
# This script runs as root.

# Bash Task Type  ##############################################################

# This ensures that the (Linux) instance can run 'bash' Tasks

# Insert 'bash' Task Type into 'application.yaml', if not already present
grep -q '"bash"' $YD_AGENT_HOME/application.yaml
if [[ $? == 1 ]]
then
  sed -i '/^yda.taskTypes:/a\  - name: "bash"\n    run: "/bin/bash"' \
      $YD_AGENT_HOME/application.yaml
fi

# End  #########################################################################
