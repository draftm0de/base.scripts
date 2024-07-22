#!/bin/bash
set -e

# todo verify base version #numeric
docker_image_get_next_tag() {
  local base_version=$1
  local latest_version=${2:-1.0.0}
  major=$(echo "$latest_version" | cut -d. -f1)
  minor=$(echo "$latest_version" | cut -d. -f2)
  patch=$(echo "$latest_version" | cut -d. -f3)

  if [[ $base_version =~ ^([0-9]+)\.([0-9]+)$ ]]; then
    b_major=$(echo "$base_version" | cut -d. -f1)
    b_minor=$(echo "$base_version" | cut -d. -f2)
    if [ -z "$b_minor" ]; then
      b_minor=1
    fi

    if [ $major -gt $b_major ]; then
      help "(get_next_image_tag) latest major version <$latest_version> cannot be greater then base major version <$base_version.1> (major)" >&2
      exit 1
    else
      if [ $minor -gt $b_minor ]; then
        help "(get_next_image_tag) latest minor version <$latest_version> cannot be greater then base minor version <$base_version.1> (minor)" >&2
        exit 1
      fi
    fi

    if [ $b_major -gt $major ]; then
      major=$b_major
      minor=0
      patch=1
    else
      if [ $b_minor -gt $minor ]; then
        minor=$b_minor
        patch=1
      else
        patch=$((patch+1))
      fi
    fi
    echo "$major.$minor.$patch"
  else
    help "(get_next_image_tag) <version> $base_version malformed, expected format [0-9].[0-9] (e.g. 2.2)" >&2
    exit 1
  fi
}
