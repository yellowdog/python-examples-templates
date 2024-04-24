# YellowDog Docker Run Script

The [docker-run.sh](docker-run.sh) script is invoked when a task of type `docker` is collected by a YellowDog worker. The arguments and environment specified in the task are passed to the script.

## Arguments

The list of arguments supplied for the task is passed directly to the invocation of the `docker run` command. Example arguments:

```shell
["--env", "MY_DOCKER_ENV_VAR=1000", "yellowdogco/test-app"]
```

## Environment Variables

The following optional environment variables can be used to control the behaviour of the script:

| Variable(s)                          | Purpose                                                                                                                             |
|--------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| `DOCKER_USERNAME`, `DOCKER_PASSWORD` | The username and password to use if registry authentication is required; these will be used with `docker login`                     |
| `DOCKER_REGISTRY`                    | The Docker registry to use; if not supplied this defaults to DockerHub                                                              |
| `YD_WORKING`                         | Working directory within the container to which the task's ephemeral YellowDog working directory is mapped (default: `/yd_working)` |
| `YD_STOP_SIGNAL`                     | The signal sent to stop the container in the case of an abort (default: `SIGTERM`)                                                  |
| `YD_STOP_TIMEOUT`                    | Seconds to wait for a container to stop gracefully before it's explicitly killed (default: 10)                                      |

## Abort/Cleanup Behaviour

When the container is started, its name is constructed using the process ID of the shell running the script. This is used if it's required to stop the container manually. In the event of a task abort, the container will be stopped using the code in the `cleanup_docker()` function, which is invoked on exit. The container will subsequently also be removed (due to the use of the `--rm` option with `docker run`).
