#!/bin/bash
# ── Kubernetes environment provisioner ───────────────────────────────────────
# Started in the background by entrypoint.sh. Brings up the in-container K3s
# cluster used by Kubernetes subject scenarios. Plain-shell subjects (Linux,
# etc.) do not depend on this — the API and terminal are up regardless.
#
# This script intentionally does NOT use `set -e`: a cluster failure here must
# not tear down the container, since other subjects remain usable.

LOG() { echo -e "\033[36m[k8s-lab]\033[0m $*"; }
OK()  { echo -e "\033[32m[k8s-lab]\033[0m ✓ $*"; }
ERR() { echo -e "\033[31m[k8s-lab]\033[0m ✗ $*" >&2; }

# ── 0. Fix cgroupv2 hierarchy (Docker Desktop / Mac) ─────────────────────────
# cgroupv2 enforces the "no-internal-process constraint": a cgroup with domain
# controllers (cpu, memory, etc.) cannot have processes AND child cgroups at the
# same level. Docker Desktop places our container's processes in the root cgroup,
# making it impossible for containerd/runc to create pod sub-cgroups (k8s.io).
#
# Fix (same as k3d): move all current processes to a leaf cgroup first, then
# enable all available controllers in the root's subtree_control.
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
  LOG "Configuring cgroupv2 delegation..."
  mkdir -p /sys/fs/cgroup/init
  # Move every process currently in the root cgroup into the leaf
  xargs -rn1 < /sys/fs/cgroup/cgroup.procs > /sys/fs/cgroup/init/cgroup.procs 2>/dev/null || true
  # Enable all available controllers for child cgroups (e.g. k8s.io, kubepods)
  sed -e 's/ / +/g' -e 's/^/+/' \
      < /sys/fs/cgroup/cgroup.controllers \
      > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || true
  OK "cgroupv2 delegation configured"
fi

# ── 1. Start k3s server ──────────────────────────────────────────────────────
LOG "Starting k3s (Kubernetes)..."

# k3s needs cgroupv2 or cgroupv1 mounted; --disable flags slim it down for lab use
k3s server \
  --disable=traefik \
  --disable=servicelb \
  --write-kubeconfig-mode=644 \
  --node-name=k8s-lab \
  --snapshotter=native \
  --kubelet-arg=cgroups-per-qos=false \
  --kubelet-arg=enforce-node-allocatable="" \
  &>/var/log/k3s.log &

# Wait for k3s API server to be ready
KUBECONFIG_PATH=/etc/rancher/k3s/k3s.yaml
for i in $(seq 1 60); do
  if [ -f "$KUBECONFIG_PATH" ] && \
     kubectl --kubeconfig="$KUBECONFIG_PATH" get nodes &>/dev/null 2>&1; then
    break
  fi
  sleep 2
  if [ $i -eq 60 ]; then
    ERR "k3s failed to start. Last log lines:"
    tail -20 /var/log/k3s.log >&2
    exit 1
  fi
done
OK "k3s API server is up"

# Symlink kubeconfig to the standard location for convenience
mkdir -p /root/.kube
cp "$KUBECONFIG_PATH" /root/.kube/config
export KUBECONFIG=/root/.kube/config

# ── 2. Wait for node to be Ready ────────────────────────────────────────────
LOG "Waiting for cluster node to become Ready..."

# Phase 1: wait until at least one node is registered
# (kubectl wait --all exits immediately with error if no resources exist yet)
# Stream k3s logs to stdout in background so failures are visible
tail -f /var/log/k3s.log &
TAIL_PID=$!

for i in $(seq 1 90); do
  NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
  if [ "$NODE_COUNT" -gt 0 ]; then
    kill $TAIL_PID 2>/dev/null || true
    break
  fi
  sleep 3
  if [ $i -eq 90 ]; then
    kill $TAIL_PID 2>/dev/null || true
    ERR "Timed out waiting for a node to register (270s)"
    ERR "k3s node status:"
    kubectl get nodes 2>&1 >&2 || true
    exit 1
  fi
done

# Phase 2: wait for the node to reach Ready condition
kubectl wait --for=condition=Ready nodes --all --timeout=120s
OK "Cluster node is Ready"

# Phase 3: wait for flannel CNI to write its subnet config.
# Pods scheduled before flannel is ready get FailedCreatePodSandBox warnings
# (missing /run/flannel/subnet.env). Waiting here avoids that noise.
for i in $(seq 1 30); do
  [ -f /run/flannel/subnet.env ] && break
  sleep 1
done

OK "Kubernetes environment ready"
