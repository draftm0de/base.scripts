#!/bin/bash
set -e

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
DOCKER_REGISTRY_SCRIPT="${SCRIPT_DIR}/docker.registry.sh"

docker_compose_push_services() {
  local arguments=("$@")

  # foreach service
  for SERVICE_NAME in $(docker compose ${arguments[@]} config --services); do

    # get image name from docker-compose.yml (node image:)
    local IMAGE_NAME=$(docker_compose_get_image_by_service "$SERVICE_NAME")
    if [ -n "$IMAGE_NAME" ]; then

      # verify if image locally already exists
      if docker_compose_image_exists "$IMAGE_NAME"; then

        # compare remote and local image digest
        if ! _compare_image_digests "$IMAGE_NAME"; then

          # push image docker (previous docker login required)
          if docker push "$IMAGE_NAME"; then
            echo "[I] image <$IMAGE_NAME> for service <$SERVICE_NAME> pushed successfully" >&2
          else
            echo "[E] image <$IMAGE_NAME> for service <$SERVICE_NAME> push failure" >&2
            return
          fi
        else
          echo "[I] image <$IMAGE_NAME> for service <$SERVICE_NAME> already exists (same digest) and will not be pushed" >&2
        fi
      else
        echo "[E] image <$IMAGE_NAME> does not exists locally, have to build it first" >&2
        return
      fi
    else
      echo "[E] no image (image node) for service <$SERVICE_NAME> found" >&2
      return
    fi
  done
}

docker_compose_get_image_by_service() {
  local SERVICE_NAME=$1
  docker compose -f docker-compose.yml config --format json | jq -r ".services[\"${SERVICE_NAME}\"].image"
}

docker_compose_image_exists() {
  local IMAGE_NAME=$1
  if docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    return 0  # Image exists
  else
    return 1  # Image does not exist
  fi
}

_compare_image_digests() {
  local IMAGE_NAME=$1
  # get remote digest by using /docker.registry.sh
  REMOTE_CMD="${DOCKER_REGISTRY_SCRIPT} manifest/digest/${IMAGE_NAME}"
  REMOTE_DIGEST=$($REMOTE_CMD)

  # get local digest by using /docker.sh
  LOCAL_CMD="${SCRIPT_DIR}/docker.sh inspect/Id ${IMAGE_NAME}"
  LOCAL_DIGEST=$($LOCAL_CMD)

  # compare both digest
  if [ "$REMOTE_DIGEST" == "$LOCAL_DIGEST" ]; then
    return 0
  else
    return 1
  fi
}

help() {
  if [ -n "$1" ]; then
    echo
    echo "[E] $1"
  fi
  echo
  echo "Usage:  ./docker.compose.sh [OPTIONS] COMMAND"
  echo
  echo "all OPTIONS and COMMANDS are forwarded in the same way you pass it to the regular [docker compose]"
  echo "we only extend some custom commands/options to provide more features"
  echo
  echo "Dependencies:"
  echo "  $DOCKER_REGISTRY_SCRIPT"
  echo
  echo "Options:"
  echo "      --debug                      the built command to be executed is displayed"
  echo
  echo "Commands:"
  echo "  push=skip-existing               only push images if their remote and local digest are different"
  echo
}

COMMAND=()
REQUIRED_FILES=()
while [[ $# -gt 0 ]]; do
  arg="$1"
  case "$arg" in
    --help)
      echo "----------------------------------------------------------------------------------------------"
      help
      echo "----------------------------------------------------------------------------------------------"
    ;;
    --debug)
      DEBUG_MODE=1
    ;;
    push=*)
      PATTERN="${arg#*=}"
      case "$PATTERN" in
        skip-existing)
          CUSTOM_CMD="docker_compose_push_services"
          REQUIRED_FILES+=("$DOCKER_REGISTRY_SCRIPT")
        ;;
        *)
          echo "<PATTERN> $PATTERN not supported"
          exit 1
      esac
    ;;
    *)
      COMMAND+=("$arg")
    ;;
  esac
  shift
done

if [ -n "$CUSTOM_CMD" ]; then
  CMD=$CUSTOM_CMD
else
  CMD="docker compose"
fi
for REQUIRED_FILE in "${REQUIRED_FILES[@]}"; do
  if [ ! -f  "${REQUIRED_FILE}" ]; then
    echo "[E] required script <$REQUIRED_FILE> does not exist"
    exit 1
  fi
done
if [ ${#COMMAND[*]} -gt 0 ]; then
  CMD="${CMD} ${COMMAND[@]}"
fi
if [ -n "$DEBUG_MODE" ]; then
  echo ${CMD}
fi
${CMD}


