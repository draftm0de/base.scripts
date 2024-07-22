#!/bin/bash
set -e

# source ./docker.sh
# source ./docker.image.sh

docker_api_get_tags() {
  local TOKEN=$1
  local REPOSITORY=$2
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: JWT $TOKEN" https://hub.docker.com/v2/repositories/$REPOSITORY/tags)
  # Check HTTP response code
  if [ "$RESPONSE" -eq 200 ]; then
      TAGS=$(curl -s -H "Authorization: JWT $TOKEN" https://hub.docker.com/v2/repositories/$REPOSITORY/tags/?page_size=100 | jq -r '.results|.[]|.name')
      echo "${TAGS}"
  elif [ "$RESPONSE" -eq 404 ]; then
      echo ""
  else
      help "(docker_api_get_tags) HTTP response code: $RESPONSE" >&2
      exit 1
  fi
}

docker_api_get_tags_latest() {
  local tags="$@"
  local highest_version="0.0.0"

  # Convert tags string to array
  IFS=$'\n' read -r -d '' -a tags_array <<< "$tags"

  # set default
  highest_major=0
  highest_minor=0
  highest_patch=0

  for tag in "${tags_array[@]}"; do
      # Check if tag matches semantic versioning pattern
      if [[ $tag =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
          # Extract major, minor, and patch versions
          major="${BASH_REMATCH[1]}"
          minor="${BASH_REMATCH[2]}"
          patch="${BASH_REMATCH[3]}"

          # Compare versions
          if [[ "$major" -gt "$highest_major" ||
                ( "$major" -eq "$highest_major" && "$minor" -gt "$highest_minor" ) ||
                ( "$major" -eq "$highest_major" && "$minor" -eq "$highest_minor" && "$patch" -gt "$highest_patch" ) ]]; then
              highest_major="$major"
              highest_minor="$minor"
              highest_patch="$patch"
              highest_version="$major.$minor.$patch"
          fi
      fi
  done
  echo "$highest_version"
}





_docker_api_get_token() {
  local USERNAME=$1
  local PASSWORD=$2
  TOKEN=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'$USERNAME'", "password": "'$PASSWORD'"}' https://hub.docker.com/v2/users/login/ | jq -r .token)
  if [ "$TOKEN" = "null" ]; then
    help "::docker_api_get_token, username/password invalid or malformed" >&2
    exit 1
  fi
  echo "$TOKEN"
}

_docker_execute_uri() {
  local URI=$1
  local USERNAME="draftmode"
  local PASSWORD="20@Docker15"
  TOKEN=$(_docker_api_get_token "$USERNAME" "$PASSWORD")
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: JWT $TOKEN" "$URI")
  if [ "$HTTP_CODE" -eq 200 ]; then
    echo $(curl -s -H "Authorization: JWT $TOKEN" $URI)
  else
    echo ":http:$HTTP_CODE: for $URI" >&2
  fi
}

docker_api_tags_digest() {
  local REPOSITORY="${1%:*}"
  local TAG="${1##*:}"
  RESPONSE=$(_docker_execute_uri "https://hub.docker.com/v2/repositories/$REPOSITORY/tags/${TAG}/")
  if [ -n "$RESPONSE" ]; then
    SHA=$(echo $RESPONSE | jq -r '.images[0].digest')
    if [ -n "$SHA" ]; then
      echo "$SHA"
    else
      help "(docker_api_get_sha) no image.digest for $1 not found" >&2
    fi
  else
    help "(docker_api_get_sha) no tag for $1 not found" >&2
  fi
}

docker_api_manifests_digest() {
  local REPOSITORY="${1%:*}"
  local TAG="${1##*:}"

  local USERNAME="draftmode"
  local PASSWORD="20@Docker15"
  local TOKEN=$(_docker_api_get_token "$USERNAME" "$PASSWORD")
  local URI="https://hub.docker.com/v2/repositories/draftmode/ionos.proxy/manifests/latest/"
  echo ":URI:$URI" >&2
  RESPONSE=$(curl -s -H "Authorization: JWT $TOKEN" "$URI")
#  RESPONSE=$(_docker_execute_uri "https://hub.docker.com/v2/repositories/$REPOSITORY/manifests/${TAG}")
echo ":RESPONSE:$RESPONSE:" >&2
  if [ -n "$RESPONSE" ]; then
    SHA=$(echo $RESPONSE | jq -r '.config.digest')
    if [ -n "$SHA" ]; then
      echo "$SHA"
    else
      help "(docker_api_manifests) no image.digest for $1 not found" >&2
    fi
  else
    help "(docker_api_manifests) no manifest for $1 not found" >&2
  fi
}

help() {
  if [ -n "$1" ]; then
    echo
    echo "[E] $1"
  fi
  echo
  echo "usage ./docker.api.sh [Command]"
  echo
  echo "Commands:"
  echo "  tags/next <repository> <version>  get next tag (base on latest and version)"
  echo "  tags <repository>                 list all tags for a given repository"
  echo
  echo "Run ./docker.api.sh --help for more information"
  echo
}

DOCKER_JSON_PATH="$HOME/.docker/config.json"
case $1 in
  --help)
    help
  ;;
  digest/*)
    IMAGE_NAME="${1#*/*}"
    DIGEST=$(docker_api_manifests_digest "${IMAGE_NAME}")
    if [ -n "$DIGEST" ]; then
      echo "$DIGEST"
    else
      exit 1
    fi
    # docker_api_manifests_digest "${IMAGE_NAME}"
  ;;
  tags/next)
    REPOSITORY=$2
    if [ -z "$REPOSITORY" ]; then
      help "argument <repository> missing"
      exit 1
    fi
    VERSION=$3
    if [ -z "$VERSION" ]; then
      help "argument <version> missing"
      exit 1
    fi
    TOKEN=$(docker_api_get_token "$DOCKER_JSON_PATH")
    TAGS=$(docker_api_get_tags "$TOKEN" "$REPOSITORY")
    if [ -n "$TAGS" ]; then
      LATEST=$(docker_api_get_tags_latest "$TAGS")
      echo $(docker_image_get_next_tag "$VERSION" "$LATEST")
    else
      echo $(docker_image_get_next_tag "$VERSION")
    fi
  ;;
  tags)
    REPOSITORY=$2
    if [ -z "$REPOSITORY" ]; then
      help "argument <repository> missing"
      exit 1
    fi
    TOKEN=$(docker_api_get_token "$DOCKER_JSON_PATH")
    TAGS=$(docker_api_get_tags "$TOKEN" "$REPOSITORY")
    if [ -n "$TAGS" ]; then
      printf '%s\n' "${TAGS[@]}" | jq -R . | jq -s .
    else
      printf "[]\n"
    fi
    ;;
  *)
    help "command <$1> not supported"
    exit 1
    ;;
esac



