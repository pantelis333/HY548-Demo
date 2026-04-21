#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed or is not on PATH." >&2
  exit 1
fi

if docker info >/dev/null 2>&1; then
  echo "Docker access already works for user ${USER}."
  exit 0
fi

if ! getent group docker >/dev/null 2>&1; then
  echo "The docker group does not exist. Is Docker Engine or Docker Desktop installed correctly?" >&2
  exit 1
fi

echo "Adding user ${USER} to the docker group. Sudo may ask for your password."
sudo usermod -aG docker "$USER"

cat <<TEXT
Done.

To use the new group in this terminal immediately, run:
  sg docker -c './scripts/setup.sh'

Or close and reopen the terminal, then run:
  ./scripts/setup.sh
TEXT

