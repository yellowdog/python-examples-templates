# Bash Script Solution Template

This directory contains simple, skeleton components for submitting and running Tasks using Bash scripts. An example [script](bash_script.sh) is provided as a starting point, and this can be extended as required.

## Prerequisites

Please ensure you've [installed the YellowDog Python Examples scripts](https://github.com/yellowdog/python-examples#script-installation-with-pip).

## Usage

All `yd-` commands described below should be run from within this (`bash`) directory.

## Configuration

The [`config-template.toml`](config-template.toml) file in this directory contains a template for the required configuration data to run the commands below.

First, copy **`config-template.toml`** to a new file **`config.toml`** in the same directory. Teh, edit the following three properties in the `config.toml` file:

1. **`key`**: Insert the Key of the YellowDog Application you wish to use
2. **`secret`**: Insert the Secret of the YellowDog Application you wish to use
3. **`templateId`**: The ID of the Compute Template to use for provisioning Worker Pools. (The ID has a form like `ydid:crt:D9C548:fa40a830-dff3-44e1-a330-8331a4a68d4a` and can be obtained from the Compute Template's page in the YellowDog Portal.)

All other properties can be left at their default values.

## Provisioning Worker Pools

```shell
yd-provision
```

The `yd-provision` command will provision a Worker Pool using the Compute Template specified by `templateId` in the `config.toml` file.

## Submitting Work Requirements

```shell
yd-submit
```

The `yd-submit` command will submit a single Bash Task for execution by one of the Workers in the Worker Pool.

When a Task is complete its console output can be inspected in the Object Store in file `taskoutput.txt`.

### Trying out Different Bash Scripts

To use your own Bash script instead of the default `bash_script.sh`, you can specify your script on the command line as follows:

```shell
yd-submit -X <my_bash_script.sh>
```

To experiment with submitting multiple Tasks with different arguments and environment variables, you can use the minimal, three-Task JSON Work Requirement specification at [`tasks.json`](tasks.json):

```shell
yd-submit --work-requirement tasks.json
```

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
