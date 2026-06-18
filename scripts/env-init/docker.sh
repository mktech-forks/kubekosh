#!/bin/bash
# ── Docker environment provisioner ───────────────────────────────────────────
# Started in the background by entrypoint.sh. Brings up an in-container Docker
# daemon (docker-in-docker) used by the Docker subject scenarios. Other subjects
# do not depend on this. Like k8s.sh, it must never tear down the container, so
# it does not use `set -e`.

LOG() { echo -e "\033[36m[docker-lab]\033[0m $*"; }
OK()  { echo -e "\033[32m[docker-lab]\033[0m ✓ $*"; }
ERR() { echo -e "\033[31m[docker-lab]\033[0m ✗ $*" >&2; }

LOG "Starting Docker daemon (dind)..."

mkdir -p /var/lib/docker /var/log

# Use the vfs storage driver: overlay2-over-overlayfs is unreliable inside a
# container (same reason k3s uses the native snapshotter). vfs is slower and
# heavier on disk but works everywhere without special mounts.
dockerd \
  --host=unix:///var/run/docker.sock \
  --storage-driver=vfs \
  &>/var/log/dockerd.log &

# Wait for the daemon socket to come up
for i in $(seq 1 30); do
  if docker info &>/dev/null; then
    OK "Docker daemon ready"
    break
  fi
  sleep 1
  if [ $i -eq 30 ]; then
    ERR "Docker daemon failed to start. Last log lines:"
    tail -20 /var/log/dockerd.log >&2
    exit 1
  fi
done

# Best-effort pre-pull of the small base images the course uses, so the first
# hands-on task isn't blocked on a registry round-trip. Non-fatal (needs
# network); scenarios still work once images are available.
LOG "Pre-pulling base images (alpine, nginx:alpine)..."
( docker pull alpine:latest && docker pull nginx:alpine ) &>/var/log/docker-pull.log \
  && OK "Base images pulled" \
  || LOG "Base image pre-pull skipped/failed (will pull on first use)"
