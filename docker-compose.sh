#!/bin/bash
set -e
SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
EXECUTE_DIR=$(pwd)

OPTIONS=()
COMMAND=()
while [[ $# -gt 0 ]]; do
  arg="$1"
  case "$arg" in
    --push-skip-equal)
      CUSTOM_CMD=1
      ;;
    -f|--file|--ansi|--env-file)
      FLAG=$1
      shift
      OPTION=$1
      OPTIONS+=("$FLAG $OPTION")
      ;;
    --*|-*)
      OPTIONS+=("$arg")
      ;;
    *)
      COMMAND+=("$arg")
      ;;
  esac
  shift
done

if [ -n "$CUSTOM_CMD" ]; then
  CMD="${SCRIPT_DIR}/docker.compose.sh"
else
  CMD="docker compose"
fi
if [ ${#OPTIONS[*]} -gt 0 ]; then
  CMD="${CMD} ${OPTIONS[@]}"
fi
if [ ${#COMMAND[*]} -gt 0 ]; then
  CMD="${CMD} ${COMMAND[@]}"
fi
echo "${CMD}"
${CMD}