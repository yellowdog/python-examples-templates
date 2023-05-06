# YellowDog Agent Installer Script

The Bash script [yd-agent-installer.sh](yd-agent-installer.sh) can be used to install and configure the YellowDog Agent and its dependencies on Linux instances running a number of different Linux distros.

Before use, the variables `NEXUS_USERNAME` and `NEXUS_PASSWORD` below must be provided, to allow download of the YellowDog Agent. Please contact YellowDog for the required credentials.

```shell
# Set the Nexus username and password below or via environment.
# These are required to download the YellowDog Agent JAR file.
NEXUS_USERNAME="${NEXUS_USERNAME:-}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-}"
```

The credentials can be set in the environment or by directly editing the script.

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
- Amazon Linux 2 (but note that Amaxon Linux 2023 doesn't currently work with YellowDog due to the requirement to use IMDSv2)
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

### Configured Worker Pool Installation

The installer script can also be used to install and configure the YellowDog Agent on systems that will be included in **Configured Worker Pools**.

Configured Worker Pools are on-premise systems, or systems that were otherwise not provisioned via the YellowDog Scheduler, e.g., instances/hosts that were provisioned directly using on-premise provisioners or via a cloud provider console. Adding the YellowDog Agent to these systems allows them to participate in YellowDog Task scheduling.

To use this feature, set the variable `CONFIGURED_WP` to `"TRUE"`. This will populate additional properties in the Agent's `application.yaml` configuration file (since these are not being set automatically as they are in the case of instances in Provisioned Worker Pools).

The following variables are available for specifying the properties of an instance. These properties are advertised by the YellowDog Agent when it connects to the Worker Pool, and can be used for matching Task Groups to Workers. Note that Only one property, `YD_TOKEN` is required. These variables can be set/exported in the environment in which the installer script runs.

| Property                 | Description                                                                                                                                         |
|--------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| `YD_TOKEN` (Required)    | This is the token that identifies the Configured Worker Pool to which this instance belongs, and which allows the Agent to connect to the platform. |
| `YD_INSTANCE_ID`         | An instance identifier, which must be unique within a Worker Pool. By default, the hostname found in `/etc/hostname` is used.                       |
| `YD_HOSTNAME`            | The hostname of the instance. By default, the hostname found in `/etc/hostname` is used.                                                            |
| `YD_REGION`              | A string describing the region in which the instance is located. Empty by default.                                                                  |
| `YD_SOURCE_NAME`         | A string describing the 'source name' from which the instance comes, e.g.: "VMware 01". Empty by default.                                           |
| `YD_INSTANCE_TYPE`       | A string describing the type of the instance. Empty by default.                                                                                     |
| `YD_WORKER_TAG`          | A string that tags the worker(s), used for matching Task Groups to Workers. Empty by default.                                                       |
| `YD_RAM`                 | The instance's RAM in GB. By default, the `MemTotal` value obtained from `/proc/meminfo`.                                                           |
| `YD_VCPUS`               | The instance's VCPU count. By default, the value returned by `nproc`.                                                                               |
| `YD_PUBLIC_IP`           | The instance's public IP address. Empty by default.                                                                                                 |
| `YD_PRIVATE_IP`          | The instance's private IP address. Empty by default.                                                                                                |
| `YD_WORKER_TARGET_COUNT` | The number of workers to create per Node or per vCPU (as determined by `YD_WORKER_TARGET_TYPE`). By default, `1`.                                   |
| `YD_WORKER_TARGET_TYPE`  | Must be set to `"PER_NODE"` or `"PER_VCPU"`. By default, `"PER_NODE"`.                                                                              |
| `YD_URL`                 | The URL of the YellowDog Platform's REST API. By default, `https://portal.yellowdog.co/api`.                                                        |
| `YD_LOG_STR`             | Specifies the format of the Agent's `log4j` output. By default, `${YD_LOG_STR:-%d{yyyy-MM-dd HH:mm:ss,SSS} [%10.10thread] %-5level %message %n}`    |
