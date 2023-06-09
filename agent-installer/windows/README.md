# Creating a YellowDog-Ready Windows Custom Image

This README provides instructions for installing and configuring the YellowDog Agent on Windows instances to be used with Provisioned Worker Pools.

There are five steps:

1. Install CloudBase-Init
2. Install the YellowDog Agent service
3. Populate the YellowDog Agent configuration file `application.yaml`
4. Create a custom image (e.g., an AWS AMI) based on the Windows instance that can be used for subsequent provisioning.
5. Register the image in a YellowDog Image Family of type Windows

The installation steps have been tested on Windows Server 2019 and Windows Server 2022, on instances running in AWS.

## (1) Download and Install CloudBase-Init

**[CloudBase-Init](https://cloudbase.it/cloudbase-init/)** runs at instance boot time and is used to set various configuration details for the YellowDog Agent. It's cloud-provider-agnostic and can also be used for other, non-YellowDog, instance preparation actions.

1. Download the installer from https://www.cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi

2. In the directory to which the file has been downloaded, run the installer from the command line as Administrator using the following, and supplying the name of the downloaded MSI file:
```
msiexec /i <name_of_installer_file>.msi /passive /l*v cloudbase-init-install.log
```
Installation will show a progress bar but will not require user interaction.

## (2) Download and Install the YellowDog Agent Service

1. The YellowDog Agent installer can be downloaded from YellowDog's Nexus software repository at: https://nexus.yellowdog.tech/repository/raw-public/agent/msi/yd-agent-5.0.3.msi. Please use the credentials supplied separately to sign in to Nexus.

The installer includes a self-contained minimal version of Java, required for Agent execution.

2. In the directory to which the file has been downloaded, run the installer from the command line as Administrator using:

```shell
msiexec /i yd-agent-5.0.3.msi /passive /log yd-agent-install.log SERVICE_STARTUP=Manual
```
Installation will show a progress bar but will not require user interaction.

## (3) Populate the YellowDog Agent Configuration File

Edit the file `C:\Program Files\YellowDog\Agent\config\application.yaml` to insert the **Task Types** that will be supported. An example populated application configuration is shown below:

```shell
yda.taskTypes:
  - name: "cmd"
    run: "cmd.exe"
  - name: "powershell"
    run: "powershell.exe"

logging.pattern.console: "%d{yyyy-MM-dd HH:mm:ss,SSS} Worker[%10.10thread] %-5level[%40logger{40}] %message [%class{0}:%method:%line]%n"
```

Note that this will set up flexible but liberal Task Types that can execute arbitrary commands on the instance. For production use, specific custom Task Type scripts are recommended.

## (4) Create a Custom Image

The instance is now ready for creation of a custom image for use with YellowDog. Make a note of the ID of the custom image that is created, for use below.

## (5) Register the Image within a YellowDog Windows Image Family

- Docs: https://docs.yellowdog.co/#/the-platform/managing-images
- Portal: https://portal.yellowdog.co/#/images

The Windows custom image must be registered within a YellowDog Windows Image Family in order for it to be correctly used within Provisioned Worker Pools.

Add a Windows Image Family (named, e.g., `win-yd-agent` in namespace `win-test`), an Image Group (e.g., `v5_0_3`) and an image (e.g., `win-2022-eu-west-2`) pointing to the image ID of the custom image you've created.

In provisioning requests, the ID or name (`yd/win-test/win-yd-agent`) of the Image Family you've just created should be used, and YellowDog will then automatically select the correct image (the most recent version applicable to the cloud provider and region).
