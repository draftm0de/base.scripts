#!/bin/bash
set -e

docker_config_get_username() {
  local DOCKER_JSON_FILE=$(docker_get_config_file)
  DECODED_AUTH=$(docker_get_config_auth "$DOCKER_JSON_FILE")
  if [ -n "$DECODED_AUTH" ]; then
    USERNAME=$(echo "$DECODED_AUTH" | cut -d':' -f1)
    if [ -n "$USERNAME" ]; then
      echo "$USERNAME"
    fi
  fi
}

docker_config_get_password() {
  local DOCKER_JSON_FILE=$(docker_get_config_file)
  if [ -f "$DOCKER_JSON_FILE" ]; then
    DECODED_AUTH=$(docker_get_config_auth "$DOCKER_JSON_PATH")
    if [ -n "$DECODED_AUTH" ]; then
      PASSWORD=$(echo "$DECODED_AUTH" | cut -d':' -f2)
      if [ -n "$PASSWORD" ]; then
        echo "$PASSWORD"
      fi
    fi
  fi
}

docker_get_config_file() {
  FILES=("$HOME/.docker/config.json")
  for FILE in "${FILES[@]}"; do
    if [ -f  "${FILE}" ]; then
      echo "${FILE}"
    fi
  done
}

docker_get_config_auth() {
  local DOCKER_JSON_FILE=$(docker_get_config_file)
  if [ -f "$DOCKER_JSON_FILE" ]; then
    local AUTH_PATTERN_1='."https://index.docker.io/v1/".auth'
    local AUTH_PATTERN_2='.auths."https://index.docker.io/v1/".auth'

    # Check the first pattern
    local AUTH_FIELD=$(jq -r "$AUTH_PATTERN_1" "$DOCKER_JSON_FILE")
    if [ -n "$AUTH_FIELD" ] && [ "$AUTH_FIELD" != "null" ]; then
      echo $(echo "$AUTH_FIELD" | base64 --decode)
      return
    fi

    # Check the second pattern
    local AUTH_FIELD=$(jq -r "$AUTH_PATTERN_2" "$DOCKER_JSON_FILE")
    if [ -n "$AUTH_FIELD" ] && [ "$AUTH_FIELD" != "null" ]; then
      echo $(echo "$AUTH_FIELD" | base64 --decode)
      return
    fi
  fi
}

help() {
  if [ -n "$1" ]; then
    echo
    echo "[E] $1"
  fi
  echo
  echo "Usage:  ./docker.sh [OPTIONS] COMMAND"
  echo
  echo "all OPTIONS and COMMANDS are forwarded in the same way you pass it to the regular [docker]"
  echo "we only extend some custom commands/options to provide more features"
  echo
  echo "Dependencies:"
  echo "  none"
  echo
  echo "Options:"
  echo "      --debug                      the built command to be executed is displayed"
  echo
  echo "Commands:"
  echo "  inspect/<pattern>                pass patterns to --format command (/ is replaced by .)"
  echo "  secrets                          get SPACE separated username and password from docker.json (docker login required)"
  echo
}

COMMAND=()
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
    secrets)
      USERNAME=$(docker_config_get_username)
      PASSWORD=$(docker_config_get_password)
      if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
        echo "$USERNAME $PASSWORD"
      fi
      exit
    ;;
    inspect/*)
      PATTERN="${arg#*/*}"
      if [ -n "$PATTERN" ]; then
        PATTERN="${PATTERN//\//.}"
        COMMAND+=("inspect")
        COMMAND+=("--format={{.$PATTERN}}")
      else
        echo "<pattern> missing"
        exit 1
      fi
    ;;
    *)
      COMMAND+=("$arg")
    ;;
  esac
  shift
done

CMD="docker"
if [ ${#COMMAND[*]} -gt 0 ]; then
  CMD="${CMD} ${COMMAND[@]}"
fi
if [ -n "$DEBUG_MODE" ]; then
  echo ${CMD}
fi
${CMD}
