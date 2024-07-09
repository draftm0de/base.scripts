# docker compose scripts

## build and push

Business Logic
1. switch to the given directory
2. verify required files **.env, docker-compose.yml**
2. run for each docker compose service
   1. get related docker-compose image directive
   2. fetch latest image tag via `docker pull --all-tags (service)`
   3. calculate a new image tag
      1. based on the lasted image tag and the **IMAGE_VERSION** set up in .env file
      2. patch version increases automatically
      3. major and minor version can be only set via .env **IMAGE_VERSION**
      4. downgrading of image tags is protected
  4. runs a docker build (for the given service)
  5. tag the built image with (IMAGE_NAME):(NEW IMAGE TAG)
  6. push the built image to docker
  7. push the tagged image to docker 
 
### GitHub workflow
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

      - name: log in to docker hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: execute build
        run: ./base.scripts/docker-compose/build-and-push/script.sh main
```


#### Navigation
[<< script collection: overview](../README.md)