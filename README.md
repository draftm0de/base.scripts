# script collection

1. [docker-compose scripts](docker-compose/README.md)

## github workflow
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
