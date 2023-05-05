# YellowDog Agent Installer Script

The Bash script [yd-agent-installer.sh](yd-agent-installer.sh) can be used to install and configure the YellowDog Agent and its dependencies on Linux instances using a number of different Linux distros.

Before use, the variables below must be populated in the script, to allow download of the YellowDog Agent. Please contact YellowDog for the required credentials.

```shell
# Uncomment and set the Nexus username and password below.
# These are required to download the YellowDog Agent JAR file.
# NEXUS_USERNAME="<INSERT YELLOWDOG NEXUS USERNAME HERE>"
# NEXUS_PASSWORD="<INSERT YELLOWDOG NEXUS PASSWORD HERE>"
```

## Script Details

The script performs the following steps:

1. Creates a new user `yd-agent` with home directory `/opt/yellowdog/agent`, and a data directory (for use during Task execution) at `/var/opt/yellowdog/agent`.
2. Optionally installs Java 11 using the Linux distro's package manager.
3. Downloads the YellowDog Agent JAR file to the `yd-agent` home directory.
4. Creates the Agent's configuration file (`application.yaml`) and its startup script.
5. Configures the Agent as a `systemd` service.
6. Optionally adds `yd-agent` to the list of passwordless sudoers.
7. Optionally adds an SSH public key for `yd-agent`.

Java installation can be suppressed if Java (v11 or greater) is already installed, by setting the environment variable `INSTALL_JAVA` in the script to anything other than `"TRUE"`. Note that the Agent startup script expects to find a Java v11+ runtime at `/usr/bin/java`.

There are optional script sections for adding the `yd-agent` user to the list of passwordless sudoers, and for adding an SSH public key. Uncomment these sections if you wish to add these features.

The script is designed to work with recent Linux distributions based on **Debian**, **Red Hat**, and **SUSE**. The following specific distributions have been tested, using AWS:

- Ubuntu 22.04
- Debian 11
- Red Hat Enterprise Linux 9.1
- CentOS Stream 8 & 9
- AlmaLinux 9.1
- Amazon Linux 2 (but note that Amaxon Linux 2023 doesn't currently work with YellowDog)
- SUSE (SLES 15 SP4)

## Modes of Use

### Custom Image Creation

The script can be used to **prepare a custom VM image**, by running it on an instance using a base image of your choice and then capturing a new custom image from this instance. Instances booted from the new custom image will be configured to work with the YellowDog Scheduler.

### Dynamic Agent Installation

The script can also be used to **install the YellowDog components dynamically** on any Linux instance, by supplying it as all or part of the **user data** for the instance. For example, the following could be specified using the Python Examples scripts as follows:

```toml
[workerPool]
userDataFile = "yd-agent-installer.sh"
```

The user data file will be run (as root) when the instance boots, and will configure the instance to work with the YellowDog Scheduler as part of the boot process. Typical total processing time for the installation steps is around 1 minute, in addition to the normal instance boot overheads.

When using dynamic Agent installation, bear in mind that **every** provisioned instance will incur the costs of installing Java using the distro's package manager (probably using cloud-local repositories for the Linux distro you're using), and also of downloading the YellowDog Agent (about 35MB in size) from YellowDog's external Nexus repository. For these reasons, we recommend against using this approach when provisioning instances at scale: use a custom image instead.
