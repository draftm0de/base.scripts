#!/bin/bash
set -e
SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

docker_compose_push_services() {
  for SERVICE_NAME in $(docker compose -f docker-compose.yml config --services); do
    IMAGE_NAME=$(docker_compose_get_image_by_service "${SERVICE_NAME}")
    if [ $(_image_digest_equal "$IMAGE_NAME") ]; then
      echo "IMAGES are different " >&2
    else
      echo "[I] image <$IMAGE_NAME> for service <$SERVICE_NAME> is equal and will not be pushed" >&2
    fi
  done
}

_image_digest_equal() {
  local IMAGE_NAME=$1
  REMOTE_CMD="${SCRIPT_DIR}/docker.api.sh digest/${IMAGE_NAME}"
#  echo "$REMOTE_CMD" >&2
  REMOTE_DIGEST=$($REMOTE_CMD)
  echo ":REMOTE_DIGEST:$REMOTE_DIGEST:" >&2
  LOCAL_CMD="${SCRIPT_DIR}/docker.sh digest/${IMAGE_NAME}"
#  echo "$LOCAL_CMD" >&2
  LOCAL_DIGEST=$($LOCAL_CMD)
  echo ":LOCAL_DIGEST:$LOCAL_DIGEST:" >&2
  if [ "$REMOTE_DIGEST" == "$LOCAL_DIGEST" ]; then
    echo ""
  fi
  echo "di"
}

docker_compose_get_image_by_service() {
  local SERVICE_NAME=$1
  docker compose -f docker-compose.yml config --format json | jq -r ".services[\"${SERVICE_NAME}\"].image"
}

OPTIONS=()
COMMAND=()
while [[ $# -gt 0 ]]; do
  arg="$1"
  case "$arg" in
    push)
      docker_compose_push_services
      ;;
  esac
  shift
done

