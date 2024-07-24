#!/bin/bash
set -e

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

DOCKER_REGISTRY_TOKEN_URI="https://auth.docker.io/token?service=registry.docker.io&scope=repository"
DOCKER_REGISTRY_URI="https://index.docker.io/v2"
DOCKER_SCRIPT="${SCRIPT_DIR}/docker.sh"

docker_registry_get_token() {
  local REPOSITORY=${1:-undefined}
  local USERNAME=${2:-unkonwn}
  local PASSWORD=${3:-unkonwn}
  local SCOPE=${4:-pull}
  TOKEN=$(curl -s -u "$USERNAME:$PASSWORD" \
        "${DOCKER_REGISTRY_TOKEN_URI}:${REPOSITORY}:${SCOPE}" | jq -r .token)
  if [ "$TOKEN" = "null" ]; then
    help "(docker_registry_get_token) username/password invalid or malformed" >&2
    exit 1
  fi
  echo "$TOKEN"
}

docker_registry_get_manifests_digest() {
  local REPOSITORY="${1%:*}"
  local TAG="${1##*:}"

  # get secrets
  local SECRET_CMD="${DOCKER_SCRIPT} secrets"
  local SECRET=$($SECRET_CMD)
  if [ -n "$SECRET" ]; then
    local SECRETS=($SECRET)
    local USERNAME="${SECRETS[0]}"
    local PASSWORD="${SECRETS[1]}"
    local TOKEN=$(docker_registry_get_token "$REPOSITORY" "$USERNAME" "$PASSWORD" "pull")
    if [ -n "${TOKEN}" ]; then
      RESPONSE=$(mktemp)
      HTTP_CODE=$(curl -s -o $RESPONSE -w "%{http_code}" -H "Authorization: Bearer $TOKEN" \
                     -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
                     "${DOCKER_REGISTRY_URI}/${REPOSITORY}/manifests/${TAG}")
      MANIFEST=$(cat $RESPONSE)
      rm $RESPONSE

      if [ "$HTTP_CODE" -eq 200 ]; then
        if [ -n "$MANIFEST" ]; then
            SHA=$(echo $MANIFEST | jq -r '.config.digest')
            if [ "$SHA" != "null" ]; then
              echo "$SHA"
            else
              help "(docker_registry_get_manifests_digest) node .config.digest in manifest not found" >&2
            fi
          else
            help "(docker_registry_get_manifests_digest) no manifest for repository $REPOSITORY:$TAG found" >&2
          fi
      else
        help "(docker_get_manifest_digest) failure to retrieve manifest for repository $REPOSITORY:$TAG, HTTP Code: $HTTP_CODE" >&2
      fi
    fi
  else
    help "(docker_get_manifest_digest) could not get any secrets to login to docker" >&2
  fi
}

help() {
  if [ -n "$1" ]; then
    echo
    echo "[E] $1"
  fi
  echo
  echo "Usage:  ./docker.registry.sh [OPTIONS] COMMAND"
  echo
  echo "Dependencies:"
  echo "  $DOCKER_SCRIPT"
  echo
  echo "Commands:"
  echo "  manifest/digest/<repository>     get manifest based digest from given repository"
  echo
}

case $1 in
  --help)
    echo "----------------------------------------------------------------------------------------------"
    help
    echo "----------------------------------------------------------------------------------------------"
    exit 0
  ;;
  manifest/digest/*)
    if [ -f "$DOCKER_SCRIPT" ]; then
      IMAGE_NAME="${1#*/*/*}"
      if [ -n "$IMAGE_NAME" ]; then
        DIGEST=$(docker_registry_get_manifests_digest "${IMAGE_NAME}")
        if [ -n "$DIGEST" ]; then
          echo "$DIGEST"
          exit 0
        fi
      else
        help "<repository> missing"
      fi
    else
      help "required script <$DOCKER_SCRIPT> does not exist"
    fi
  ;;
esac
exit 1



