# YellowDog Quickstart for Provisioned Worker Pools

The basic Workflow for getting started with YellowDog is described at https://docs.yellowdog.co/#/the-platform/workflow.
 
Summarised below are the minimal steps necessary to prepare for creating YellowDog Provisioned Worker Pools (collections of VM instances running the YellowDog Agent). The steps are performed using your account in the YellowDog Portal: https://portal.yellowdog.co/ (so a YellowDog Platform account is required), and you’ll need various pieces of cloud provider information including credentials and network details.
 
Once you’ve completed the steps below, you’ll be ready to provision instances and run workloads via YellowDog.
 
## Step 1: Create a Keyring and add a Cloud Provider Credential
 
- Docs: https://docs.yellowdog.co/#/the-platform/keyrings
- Portal: https://portal.yellowdog.co/#/keyrings
 
Create a **Keyring** using the Keyrings tab. Make a note of the Keyring password (it won’t be shown again).

Within the Keyring, add one or more cloud provider **Credentials** for the cloud accounts you want YellowDog to use for VM provisioning.
 
Note that Keyrings are not automatically shared with other users in your YellowDog account. Users must explicitly claim access to each Keyring using the Keyring name and the Keyring password.

### Cloud-Provider-Specific Requirements

**AWS** credentials must have the **[required IAM policies](https://docs.yellowdog.co/#/knowledge-base/configuring-an-aws-account-for-use-with-yellowdog)**.
 
## Step 2: Create a Source Template
 
- Docs: https://docs.yellowdog.co/#/the-platform/specifying-sources-of-compute
- Portal: https://portal.yellowdog.co/#/sources
 
Create a **Source** using the Source Templates tab. You’ll need various bits of cloud provider information.

**Networking requirements**: For the YellowDog Agent to connect back to the YellowDog Platform, instances must have the ability to make **outbound HTTPS connections**. This is usually handled automatically if the public IP address option is selected, otherwise it may be necessary to ensure that the selected network has a suitable gateway configured. No inbound connections are required.
 
Leave the Instance Type and Image ID as ‘Allow Any’. We’ll allow these to be populated at the Compute Template level.
 
## Step 3: Create a Compute Template
 
- Docs: https://docs.yellowdog.co/#/the-platform/creating-a-static-template
- Portal: https://portal.yellowdog.co/#/templates
 
Create a **Compute Template** using the Compute Templates tab.
 
Create a simple **Static Template** including the Source you created above. Specify the required Instance Type in the Source panel and choose the **‘yd/yellowdog/yd-agent-docker’** image family from the **Images Id** drop-down.
  
## Step 4: Test-Provision a Worker Pool
 
- Docs: https://docs.yellowdog.co/#/the-platform/provisioning-a-worker-pool
- Portal: https://portal.yellowdog.co/#/workers
 
From the Workers tab in the Portal, click on the Add Provisioned Worker Pool button, select your Worker Pool preferences, and provision the pool.

Once instances have booted, you should see their YellowDog Workers advertised in their Worker Pool.
 
Finally, shut down the Worker Pool, which will deprovision all its instances.
 
## Step 5: Create an Application
 
- Docs: https://docs.yellowdog.co/#/the-platform/applications
- Portal: https://portal.yellowdog.co/#/account/applications
 
Create an **Application** using the Account -> Application tab.
 
Make a note of the Application Key and Secret (they won’t be shown again) and give the Application access to your Keyring. You’ll use these later for API access to the Platform.

## Next Steps

Once the steps above are completed, you'll be ready to experiment with the template solutions in this repository.