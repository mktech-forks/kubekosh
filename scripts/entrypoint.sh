#!/bin/bash
# Note: deliberately no `set -e`. The web UI, API and plain-shell subjects must
# come up even if a specific environment provisioner (e.g. K3s) fails.

LOG() { echo -e "\033[36m[k8s-lab]\033[0m $*"; }
OK()  { echo -e "\033[32m[k8s-lab]\033[0m ✓ $*"; }
ERR() { echo -e "\033[31m[k8s-lab]\033[0m ✗ $*" >&2; }

LOG "Starting KubeKosh..."

# ── 1. Launch environment provisioners (background, non-blocking) ────────────
# Each subject declares an `environment`; the matching provisioner in
# scripts/env-init/ prepares its runtime (K3s for Kubernetes, etc.). They run in
# the background so the API/terminal and plain-shell subjects are available
# immediately rather than waiting on a cluster. Adding Docker/cloud support later
# = drop a new scripts/env-init/<env>.sh; no change needed here.
ENV_INIT_DIR=/app/scripts/env-init
if [ -d "$ENV_INIT_DIR" ]; then
  for f in "$ENV_INIT_DIR"/*.sh; do
    [ -e "$f" ] || continue
    LOG "Launching environment init: $(basename "$f")"
    bash "$f" &
  done
fi

# ── 2. Shell environment ─────────────────────────────────────────────────────
LOG "Configuring shell environment..."

cat >> /root/.bashrc << 'BASHRC'

# KubeKosh aliases
export KUBECONFIG=/root/.kube/config
alias k='kubectl'
alias kgp='kubectl get pods'
alias kga='kubectl get pods --all-namespaces'
alias kgd='kubectl get deployments'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kgns='kubectl get namespaces'
alias kdp='kubectl describe pod'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
alias kg='kubectl get'
alias kd='kubectl describe'
alias krm='kubectl delete'
alias kex='kubectl exec -it'
alias klogs='kubectl logs'

# Useful functions
kns() { kubectl config set-context --current --namespace="$1"; }
kctx() { kubectl config use-context "$1"; }

source <(kubectl completion bash) 2>/dev/null || true
complete -F __start_kubectl k 2>/dev/null || true

PS1='\[\033[01;32m\]\u@k8s-lab\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

echo ""
echo "  ⎈ KubeKosh"
KUBECTL_VER=$(kubectl version --client 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+[^ ]*' | head -1)
echo "    kubectl ${KUBECTL_VER}"
echo "    Aliases: k=kubectl, kgp=get pods, kaf=apply -f, kns=set-namespace, kgns=get namespaces, kex=kubectl exec -it"
echo "             kgd=get deployments, kgn=get nodes, kgs=get services, kdp=describe pod, krm=kubectl delete, klogs=kubectl logs"
echo ""
BASHRC

OK "Shell configured"

# ── 3. Start Node.js API server ──────────────────────────────────────────────
LOG "Starting API server..."
cd /app/backend && node server.js &>/var/log/api.log &
OK "API server started (port 4000)"

# ── 4. Browser terminal ──────────────────────────────────────────────────────
# Terminal is served via WebSocket at /shell-ws by the Node.js API server
# using node-pty — no external ttyd binary needed.


# ── 5. Start nginx reverse proxy ────────────────────────────────────────────
LOG "Starting nginx proxy..."
nginx -g 'daemon off;' &>/var/log/nginx.log &
OK "nginx started (port 80)"

# ── 6. Keep Alive & Graceful Shutdown ────────────────────────────────────────
cleanup() {
  LOG "Caught signal, shutting down KubeKosh..."
  # k3s/dockerd may have been started by background env-init scripts
  # (grandchildren), so target them by name in addition to killing our jobs.
  pkill -TERM k3s 2>/dev/null || true
  pkill -TERM dockerd 2>/dev/null || true
  kill $(jobs -p) 2>/dev/null || true
  exit 0
}

trap cleanup SIGINT SIGTERM

LOG "══════════════════════════════════════════════════"
LOG "   KubeKosh is ready!  →  http://localhost:7554   "
LOG "══════════════════════════════════════════════════"

# Wait for background jobs. When a signal is caught, wait returns instantly and triggers cleanup.
wait
