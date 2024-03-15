#!/bin/bash

################################################################################
# Clean up Docker container on Task Abort

# Disambiguate container name using the Bash process ID
YD_CONTAINER_NAME=yd-container-$$

cleanup_docker() {
  CONTAINER_ID=$(docker ps -aq --filter name=$YD_CONTAINER_NAME)
  if [ -n "$CONTAINER_ID" ]
  then
    echo "Abort received at: $(date -u "+%Y-%m-%d_%H%M%S_UTC")"
    if [ -n "$YD_STOP_SIGNAL" ]
    then
      echo "YD_STOP_SIGNAL = $YD_STOP_SIGNAL"
    fi
    if [ -n "$YD_STOP_TIMEOUT" ]
    then
      echo "YD_STOP_TIMEOUT = $YD_STOP_TIMEOUT"
    fi
    echo "Stopping container: $YD_CONTAINER_NAME ($CONTAINER_ID)"
    docker stop --time ${YD_STOP_TIMEOUT:-10} $CONTAINER_ID > /dev/null
    echo "Done"
  fi
  # Remove Docker login credentials on Task exit
  if [[ "$DOCKER_USERNAME" ]]
  then
    docker logout "$DOCKER_REGISTRY"
  fi
}

# Trap EXIT signal and run the cleanup function
trap cleanup_docker EXIT

################################################################################

# Run docker login if environment variables are set
[[ ! -z "$DOCKER_PASSWORD" && ! -z "$DOCKER_USERNAME" ]] && \
  docker login -u "$DOCKER_USERNAME" -p "$DOCKER_PASSWORD" "$DOCKER_REGISTRY"

# Default YD_WORKING if not set
[ -z "$YD_WORKING" ] && export YD_WORKING="/yd_working"

# Run docker command
docker run --rm --name $YD_CONTAINER_NAME \
  --stop-signal ${YD_STOP_SIGNAL:-SIGTERM}  \
  --user $(id -u):$(id -g) \
  --env YD_WORKING="$YD_WORKING" -v "$(pwd)":$YD_WORKING "$@"

################################################################################
