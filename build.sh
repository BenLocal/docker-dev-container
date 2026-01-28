#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional: change this prefix to control the built image name
IMAGE_NAME_PREFIX="docker-dev-container"

usage() {
  cat <<EOF
Usage: $(basename "$0") [noble|jammy|focal|all] [--push] [--repo <your-repo>]

Examples:
  $(basename "$0") noble
  $(basename "$0") jammy
  $(basename "$0") focal
  $(basename "$0") all
  $(basename "$0") all --repo myuser --push

Description:
  - Selects the corresponding cruizba/ubuntu-dind:* base image based on Ubuntu version:
      noble -> cruizba/ubuntu-dind:noble-systemd-29.1.4
      jammy -> cruizba/ubuntu-dind:jammy-systemd-29.1.4
      focal -> cruizba/ubuntu-dind:focal-systemd-28.1.1-r1
  - Automatically passes the corresponding value to ARG BASE_TAG in the Dockerfile.
  - If --repo is specified, the final tag is <repo>/<IMAGE_NAME_PREFIX>:<version>, otherwise <IMAGE_NAME_PREFIX>:<version>.
  - If --push is provided, docker push will be executed after a successful build.
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

TARGET="$1"
shift

PUSH=0
REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push)
      PUSH=1
      shift
      ;;
    --repo)
      REPO="${2:-}"
      if [[ -z "$REPO" ]]; then
        echo "ERROR: --repo requires a value"
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

build_one() {
  local version="$1"      # noble / jammy / focal
  local base_tag="$2"     # noble-systemd-29.1.4 etc.

  local tag="${IMAGE_NAME_PREFIX}:${version}"
  if [[ -n "$REPO" ]]; then
    tag="${REPO}/${tag}"
  fi

  echo "=============================="
  echo "Start building version: ${version}"
  echo "  Base image: cruizba/ubuntu-dind:${base_tag}"
  echo "  Target image tag: ${tag}"
  echo "=============================="

  docker build \
    --build-arg BASE_TAG="${base_tag}" \
    -t "${tag}" \
    "${ROOT_DIR}"

  echo "Build completed: ${tag}"

  if [[ "$PUSH" -eq 1 ]]; then
    echo "Pushing image: ${tag}"
    docker push "${tag}"
  fi
}

case "$TARGET" in
  noble)
    build_one "noble" "noble-systemd-29.1.4"
    ;;
  jammy)
    build_one "jammy" "jammy-systemd-29.1.4"
    ;;
  focal)
    build_one "focal" "focal-systemd-28.1.1-r1"
    ;;
  all)
    build_one "noble" "noble-systemd-29.1.4"
    build_one "jammy" "jammy-systemd-29.1.4"
    build_one "focal" "focal-systemd-28.1.1-r1"
    ;;
  *)
    echo "Unsupported target version: $TARGET"
    usage
    exit 1
    ;;
esac

echo "All tasks finished."

