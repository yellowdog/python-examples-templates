# Slurm Cluster Example Template

This directory contains simple, skeleton components for provisioning a Slurm cluster and submitting Work Requirements consisting of simple `srun` and `sbatch` Slurm jobs.

## Prerequisites

Please ensure you've [installed the YellowDog Python Examples scripts](https://github.com/yellowdog/python-examples#script-installation-with-pip) and that you've set up your YellowDog account.

1. You will need an Application Key and Secret, created within your YellowDog account.
2. You will need a Compute Requirement Template using your selected Compute Source Template(s) and Instance Type(s). Leave the `Images Id` property in the Compute Requirement Template blank.

## Configuration

The [`config-template.toml`](config-template.toml) file in this directory contains a template for the required configuration data to run the YellowDog commands below.

First, copy **`config-template.toml`** to a new file **`config.toml`** in the same directory.

Then, edit the following three properties in the `config.toml` file:

1. **`key`**: Insert the Key of the YellowDog Application you wish to use
2. **`secret`**: Insert the Secret of the YellowDog Application you wish to use
3. **`templateId`**: The ID or name of the Compute Template to use for provisioning Worker Pools.

All other properties can be left at their default values.

## Usage

All `yd-` commands described below should be run from within this (`slurm-cluster`) directory.

## Provisioning a Slurm Cluster Worker Pool

```shell
yd-provision
```

This will provision a five node Worker Pool which autoconfigures itself into a Slurm cluster. One of the nodes is configured to be the Slurm controller and NFS server, and will host a YellowDog Worker that accepts `srun` or `sbatch` Tasks that will be added to the Slurm queue.

The specification of the Worker Pool is found in [wp_slurm.json](wp_slurm.json). This is an example of an **Advanced Worker Pool** because it contains differentiated node types.

## Submitting Work Requirements

```shell
yd-submit
```

The `yd-submit` command will submit a Task consisting of single Slurm `sbatch` job for execution by the Slurm cluster Worker Pool. When a Task is complete its console output can be inspected in the YellowDog Object Store in file `taskoutput.txt`, along with any specified task output files.

## Downloading Results

```shell
yd-download
```

The `yd-download` command will download the results of your Work Requirements to your local filesystem.

## Cancelling Work Requirements

```shell
yd-cancel
```

This will cancel any Work Requirements that are still running. (Add the `--abort` option to abort any currently running Tasks, otherwise they'll run to completion.)

## Shutting Down Worker Pools

```shell
yd-shutdown
```

The `yd-shutdown` command will shut down your Worker Pool(s).

Note that Worker Pools will automatically shut down after a default idle timeout of 30 minutes.

## Deleting YellowDog Objects

```shell
yd-delete
```

The `yd-delete` command cleans up all of your objects in the YellowDog Object Store, using the `namespace` and `tag` for matching.
