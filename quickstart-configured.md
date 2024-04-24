# YellowDog Quickstart for Configured Worker Pools
 
Summarised below are the minimal steps necessary to create YellowDog Configured Worker Pools, which are collections of customer-managed nodes running the YellowDog Agent, e.g., on-premise systems.

Some steps are performed using your account in the YellowDog Portal: https://portal.yellowdog.co/ (so a YellowDog Platform account is required).
 
Once you’ve completed the steps below, you’ll be ready to populate your Configured Worker Pool and submit work via YellowDog.
 
## Step 1: Create a Configured Worker Pool
 
- Docs: https://docs.yellowdog.co/#/the-platform/using-on-premise-compute
- Portal: https://portal.yellowdog.co/#/workers
 
Use the **Add Configured Worker Pool** button to create a new Configured Worker Pool. This is the Pool to which the Workers on your Configured nodes will register.

Record the **Worker Pool Token** (a string of the form `aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee`). This is the token the YellowDog Agent running on your Nodes will use to authenticate with the YellowDog Platform and to register with the correct Worker Pool.

**Networking requirements**: For the YellowDog Agent to connect back to the YellowDog Platform, the nodes must have the ability to make **outbound HTTPS connections**. No inbound connections are required.
 
## Step 2: Install the YellowDog Agent on the Configured Nodes

To install the YellowDog Agent on a Linux system, please see the **[Configured Worker Pool](https://github.com/yellowdog/resources/tree/main/agent-install/linux#configured-worker-pool-installation)** section of the Linux installation README.

To install on Windows, please see **[Setting up a Windows Configured Worker Pool Node](https://github.com/yellowdog/resources/blob/main/agent-install/windows/README-CONFIGURED.md)**.

Once installation is complete, the nodes should appear in your Configured Worker Pool.
 
## Step 3: Create an Application
 
- Docs: https://docs.yellowdog.co/#/the-platform/applications
- Portal: https://portal.yellowdog.co/#/account/applications
 
Create an **Application** using the Account -> Application tab.
 
Make a note of the Application Key and Secret (they won’t be shown again), and make the Application a member of the `administrators` group. You’ll use the Key and Secret later for API access to the Platform.

## Next Steps

Once the steps above are completed, you'll be ready to experiment with the template solutions in this repository, to submit Work Requirements to your Worker Pool.
