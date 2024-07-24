# script collection

## docker.sh
```
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
```
## docker.compose.sh
```
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
```
## docker.registry.sh
```
  echo
  echo "Usage:  ./docker.registry.sh [OPTIONS] COMMAND"
  echo
  echo "Dependencies:"
  echo "  $DOCKER_SCRIPT"
  echo
  echo "Commands:"
  echo "  manifest/digest/<repository>     get manifest based digest from given repository"
  echo
```

## GitHub workflow
```
name: Build and Push Images

on:
  workflow_dispatch:

jobs:
  build_push_image:
    name: build and push to registry
    runs-on: ubuntu-latest
    steps:
      - name: checkout base.scripts repository and map as base.scripts
        uses: actions/checkout@v4
        with:
          repository: draftm0de/base.scripts
          # map repository as
          path: base.scripts
          # tag to be used
          ref: main

      - name: checkout own repository and map as main
        uses: actions/checkout@v4
        with:
          path: main

      - name: make base.script executable
        run: |
          chmod +x base.scripts/docker-compose/build-and-push/script.sh
```
