IMAGE_NAME=libre-stage

DOCKER_BUILDKIT=1 docker build --rm -t $IMAGE_NAME "$(dirname "$0")"
