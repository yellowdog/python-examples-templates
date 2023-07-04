# Slurm Cluster Example Template

This directory contains simple, skeleton components for provisioning a Slurm cluster and submitting Work Requirements to it consisting of simple `srun` commands.

## Prerequisites

Please ensure you've [installed the YellowDog Python Examples scripts](https://github.com/yellowdog/python-examples#script-installation-with-pip) and that you've set up your YellowDog account. At a minimum, you'll need an Application Key and Secret, and a Compute Template ID.

The Compute Template must specify the **`yd-agent-slurm`** image family.

## Usage

All `yd-` commands described below should be run from within this (`slurm-cluster`) directory.

## Configuration

The [`config-template.toml`](config-template.toml) file in this directory contains a template for the required configuration data to run the commands below.

First, copy **`config-template.toml`** to a new file **`config.toml`** in the same directory. Then, edit the following three properties in the `config.toml` file:

1. **`key`**: Insert the Key of the YellowDog Application you wish to use
2. **`secret`**: Insert the Secret of the YellowDog Application you wish to use
3. **`templateId`**: The ID of the Compute Template to use for provisioning Worker Pools. (The ID has a form like `ydid:crt:D9C548:fa40a830-dff3-44e1-a330-8331a4a68d4a` and can be obtained from the Compute Template's page in the YellowDog Portal.)

All other properties can be left at their default values.

## Provisioning a Slurm Cluster Worker Pool

```shell
yd-provision
```

This will provision a five node Worker Pool which autoconfigures into a Slurm cluster. One of the nodes will be the Slurm controller and will host a YellowDog Worker for accepting `srun` Tasks, the others will be Slurm worker nodes.

The definition of the Worker Pool is found in [wp_slurm.json](wp_slurm.json).

## Submitting Work Requirements

```shell
yd-submit
```

The `yd-submit` command will submit a Task consisting of single Slurm (`srun`) job for execution by the Slurm cluster. When a Task is complete its console output can be inspected in the Object Store in file `taskoutput.txt`.

## Downloading Results

```shell
yd-download
```

The `yd-download` command will download the results of your Work Requirements to your local filesystem, in a directory named using the `namespace` property.

## Cancelling Work Requirements

```shell
yd-cancel
```

This will cancel any Work Requirements that are still running. (Add the `--abort` option to abort any currently running Tasks, otherwise they'll run to completion.)

## Shutting Down Worker Pools

```shell
yd-shutdown
```

The `yd-shutdown` command will shut down your Worker Pool(s). Note that Worker Pools will automatically shut down after being idle for the period of time specified in the `config.toml` file.

### Deleting YellowDog Objects

```shell
yd-delete
```

The `yd-delete` command cleans up all of your objects in the YellowDog Object Store, using the `namespace` and `tag` for matching.
