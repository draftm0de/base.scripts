#!/bin/bash
set -e

docker_config_get_username() {
  local DOCKER_JSON_PATH=$1
  DECODED_AUTH=$(_docker_config_auth "$DOCKER_JSON_PATH")
  if [ -z "$DECODED_AUTH" ]; then
    exit 1
  fi
  USERNAME=$(echo "$DECODED_AUTH" | cut -d':' -f1)
  if [ -z "$USERNAME" ]; then
    echo "[E] <username> could not be extracted" >&2
    exit 1
  fi
  echo "$USERNAME"
}

docker_config_get_password() {
  local DOCKER_JSON_PATH=$1
  DECODED_AUTH=$(_docker_config_auth "$DOCKER_JSON_PATH")
  if [ -z "$DECODED_AUTH" ]; then
    exit 1
  fi
  PASSWORD=$(echo "$DECODED_AUTH" | cut -d':' -f2)
  if [ -z "$PASSWORD" ]; then
    echo "[E] <password> could not be extracted" >&2
    exit 1
  fi
  echo "$PASSWORD"
}

_docker_config_auth() {
  local DOCKER_JSON_PATH=$1
  if [ ! -f "$DOCKER_JSON_PATH" ]; then
    echo "[E] file <$DOCKER_JSON_PATH> does not exist" >&2
    exit 1
  fi
  local AUTH_PATTERN_1='."https://index.docker.io/v1/".auth'
  local AUTH_PATTERN_2='.auths."https://index.docker.io/v1/".auth'

  # Check the first pattern
  local AUTH_FIELD=$(jq -r "$AUTH_PATTERN_1" "$DOCKER_JSON_PATH")
  if [ -n "$AUTH_FIELD" ] && [ "$AUTH_FIELD" != "null" ]; then
    echo $(echo "$AUTH_FIELD" | base64 --decode)
    return
  fi

  # Check the second pattern
  local AUTH_FIELD=$(jq -r "$AUTH_PATTERN_2" "$DOCKER_JSON_PATH")
  if [ -n "$AUTH_FIELD" ] && [ "$AUTH_FIELD" != "null" ]; then
    echo $(echo "$AUTH_FIELD" | base64 --decode)
    return
  fi
  echo "[E] could not extract any .auth node from $DOCKER_JSON_PATH" >&2
  exit 1
}

docker_get_digest() {
  local REPOSITORY="${1%:*}"
  local TAG="${1##*:}"
  # DIGEST=$(docker images --digests | awk -v img="${REPOSITORY}" -v tag="${TAG}" '$1 == img && $2 == tag {print $3}')
  DIGEST=$(docker image inspect $1 --format='{{.Id}}')
  if [ -n "$DIGEST" ]; then
    echo "$DIGEST"
  fi

}

help() {
  if [ -n "$1" ]; then
    echo
    echo "[E] $1"
  fi
  echo
  echo "usage ./docker.sh [Command]"
  echo
  echo "Commands:"
  echo "  digest/<repository>   get digests from local repository"
  echo
  echo "Run ./docker.sh --help for more information"
  echo
}

case $1 in
  --help)
    help
  ;;
  digest/*)
    IMAGE_NAME="${1#*/*}"
    DIGEST=$(docker_get_digest "${IMAGE_NAME}")
    if [ -n "$DIGEST" ]; then
      echo "$DIGEST"
    else
      help "(docker_get_digest) no digest for image <$1> not found"
      exit 1
    fi
  ;;
  *)
    help "argument $1 not supported"
    exit 1
    ;;
esac
