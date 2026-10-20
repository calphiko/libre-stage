IMAGE_NAME=libre-stage

DOCKER_BUILDKIT=1 docker build --rm --no-cache -t $IMAGE_NAME .
