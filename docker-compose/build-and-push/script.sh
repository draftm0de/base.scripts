#!/bin/bash

change_working_directory() {
  local path=$1
  cd $path
}

docker_logged_in() {
  username=$(docker info 2>&1 | grep "Username: ")
}

check_required_files() {
  files=(.env docker-compose.yml)
  for file in "${files[@]}"; do
    if [ ! -f "$file" ]; then
      echo "**error** required file <$file> does not exist"
      return
    fi
  done
}

get_image_name() {
  local service_name=$1
  docker compose -f docker-compose.yml config --format json | jq -r ".services[\"${service_name}\"].image"
}

get_base_image_tag() {
  if [ -f ".env" ]; then
    source ".env"
    echo "${IMAGE_VERSION:-1.0}"
  else
    echo "1.0"
  fi
}

get_last_image_tag() {
  local image_name=$1
  local last_version=$(docker pull --all-tags $image_name 2>&1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | sort -Vr | head -n 1)
  echo ${last_version:-"1.0.-1"}
}

is_valid_image_tag() {
  local base_version=$1
  local latest_version=$2
  major=$(echo "$latest_version" | cut -d. -f1)
  minor=$(echo "$latest_version" | cut -d. -f2)
  patch=$(echo "$latest_version" | cut -d. -f3)

  b_major=$(echo "$base_version" | cut -d. -f1)
  b_minor=$(echo "$base_version" | cut -d. -f2)

  failure="-"
  if [ $major -gt $b_major ]; then
    failure="**error** latest version $latest_version cannot be after then base version $base_version.0 (major)"
  else
    if [ $minor -gt $b_minor ]; then
      failure="**error** latest version $latest_version cannot be after then base version $base_version.0 (minor)"
    fi
  fi
  echo $failure
}

get_next_image_tag() {
  local base_version=$1
  local latest_version=$2
  major=$(echo "$latest_version" | cut -d. -f1)
  minor=$(echo "$latest_version" | cut -d. -f2)
  patch=$(echo "$latest_version" | cut -d. -f3)

  b_major=$(echo "$base_version" | cut -d. -f1)
  b_minor=$(echo "$base_version" | cut -d. -f2)

  if [ $b_major -gt $major ]; then
    major=$b_major
    minor=0
    patch=1
  else
    if [ $b_minor -gt $minor ]; then
      minor=$b_minor
      patch=0
    else
      patch=$((patch+1))
    fi
  fi
  echo "$major.$minor.$patch"
}

if [ ! -d "$1" ]; then
  if [ -z $1 ]; then
    echo "**error** first argument [path] is missing"
  else
    echo "**error** path <$1> does not exist"
  fi
  exit 1
fi

# verify if docker logged in
if ! docker_logged_in; then
  echo "**error** docker login missing"
  exit 1
fi


# change working directory
cd $1
if ! check_required_files; then
  exit 1
fi

for service in $(docker compose -f docker-compose.yml config --services); do
  full_image_name=$(get_image_name "${service}")
  image_name="${full_image_name%:*}"
  image_tag="${full_image_name##*:}"
  if [ $image_name = "null" ]; then
    echo "**error** no image directive for service ${service} found"
    exit 1
  else
    echo "[I] image name: $image_name"
    base_image_tag=$(get_base_image_tag)
    echo "[I] base image tag: $base_image_tag.0 (.env)"
    last_image_tag=$(get_last_image_tag "$image_name")
    echo "[I] last image tag: $last_image_tag (registry)"
    valid_image_tag=$(is_valid_image_tag "$base_image_tag" "$last_image_tag")
    if [ "$valid_image_tag" = "-" ]; then
      next_image_tag=$(get_next_image_tag "$base_image_tag" "$last_image_tag")
      echo "[I] next image tag: $next_image_tag"

      echo "[I] building docker image for service $service"
      docker compose -f docker-compose.yml build --no-cache --force-rm ${service}

      echo "[I] tag image with $image_name:$next_image_tag"
      docker tag $image_name:$image_tag $image_name:$next_image_tag

      echo "[I] push image $image_name:$next_image_tag"
      docker image push $image_name:$next_image_tag

      echo "[I] push image $image_name:$image_tag"
      docker image push $image_name:$image_tag
    else
      echo $valid_image_tag
      exit 1
    fi
  fi
done
