<div align="center">
  <img src="frontend/public/logo.svg" alt="KubeKosh Logo" width="100" />

  <h1>KubeKosh</h1>

  <p><strong>Self-hosted Kubernetes Lab for Hands-on Learning</strong></p>

  <p>
    <a href="https://hub.docker.com/r/zeborg/kubekosh"><img src="https://img.shields.io/docker/pulls/zeborg/kubekosh?style=flat-square&logo=docker&label=Docker%20Hub" alt="Docker Hub" /></a>
    <img src="https://img.shields.io/badge/license-Apache%202.0-blue?style=flat-square" alt="License" />
    <img src="https://img.shields.io/badge/platforms-amd64%20%7C%20arm64-lightgrey?style=flat-square" alt="Platforms" />
  </p>
</div>

---

KubeKosh runs a real [K3s](https://k3s.io/) Kubernetes cluster inside a single Docker container and pairs it with a browser-based terminal and automated scenario validation — no cloud account or local cluster required.

## Screenshots

| | |
|---|---|
| ![Scenario browser with live terminal](screenshots/1.png) | ![Task scenario with problem statement](screenshots/2.png) |
| ![Contextual hints with copy-ready commands](screenshots/3.png) | ![Automated validation — all checks passed](screenshots/4.png) |
| ![Exam mode — start with custom duration](screenshots/5.png) | ![Exam mode - live exam with timer](screenshots/6.png) |
| ![Multiple-choice question view](screenshots/7.png) | ![MCQ with correct answer and explanation](screenshots/8.png) |

---

## Quick Start

**Prerequisite:** [Docker](https://docs.docker.com/get-docker/)

```bash
docker run -itd --name kubekosh --privileged -p 7554:80 zeborg/kubekosh:latest
```

Open **http://localhost:7554** — wait ~30 seconds for the *Cluster Ready* indicator to turn green.

> `--privileged` is required — K3s needs access to kernel namespaces and cgroups.

### Persist Progress

```bash
docker run -itd --name kubekosh --privileged -p 7554:80 \
  -v <your_custom_directory>:/data zeborg/kubekosh:latest
```

Progress is stored in SQLite at `/data/progress.db` inside the container. You may mount your own custom directory to `/data` to persist the progress across container restarts.

### Build From Source

```bash
docker build -t kubekosh .
# multi-platform
docker buildx build --platform linux/amd64,linux/arm64 -t kubekosh .
```

---

## What's Inside

| Bundle | Focus | Exam Mode |
|---|---|---|
| 🌱 Kubernetes Basics | Core concepts | 60 min |
| 🧑‍✈️ Kubernetes Administrator | CKA | 120 min |
| 🛠️ Kubernetes Developer | CKAD | 120 min |
| 🛡️ Kubernetes Security | CKS | 120 min |

**Scenario types:**
- **Task** — Hands-on challenge in the live terminal. Click **Validate** for automated cluster-state checking.
- **MCQ** — Multiple-choice question with a detailed explanation on submission.

### Shell Aliases

The terminal comes pre-configured with:

| Alias | Expands to |
|---|---|
| `k` | `kubectl` |
| `kgp` | `kubectl get pods` |
| `kga` | `kubectl get pods --all-namespaces` |
| `kgd` | `kubectl get deployments` |
| `kgs` | `kubectl get services` |
| `kaf` | `kubectl apply -f` |
| `kex` | `kubectl exec -it` |
| `kns <ns>` | `kubectl config set-context --current --namespace=<ns>` |

---

## Architecture

| Component | Technology |
|---|---|
| Frontend | React + Vite, `xterm.js` |
| Backend | Node.js / Express, `node-pty` WebSocket PTY |
| Cluster | K3s (single-node, in-container) |
| Proxy | nginx on container port `80`, mapped to host port `7554` |
| Storage | SQLite (`better-sqlite3`) at `/data/progress.db` |

Everything runs inside a **single Docker image** managed by `scripts/entrypoint.sh`.

---

## Contributing

Contributions are what make open-source projects like this one grow — and every contribution counts, big or small. Whether you're fixing a typo, polishing a scenario description, or building a completely new exercise from scratch, you're helping the next person learn Kubernetes in the best way possible. **Thank you for taking the time!**

### Adding Scenarios

Scenarios live in `scenarios/scenarios.json`; bundles in `scenarios/bundles.json`. See [`scenarios/SCHEMA.md`](scenarios/SCHEMA.md) for the full schema.

**Task checklist:**
- `validation.commands` — idempotent `kubectl` commands only
- `setup_commands` / `teardown_commands` — `kubectl` or native Ubuntu commands only

**MCQ checklist:**
- `correct_option` must match one of the `options[].id` values
- Always include an `explanation`

### Workflow

```bash
# 1. Fork the repo on GitHub, then clone your fork
git clone https://github.com/<your-username>/kubekosh.git
cd kubekosh

# 2. Create a branch
git checkout -b feat/my-scenario

# 3. Edit scenarios/scenarios.json (and/or bundles.json)

# 4. Build and test locally
docker build -t kubekosh . && docker run --rm -itd --privileged -p 7554:80 kubekosh

# 5. Commit and push to your fork
git add scenarios/scenarios.json
git commit -m "feat: add <scenario-name> scenario"
git push -u origin feat/my-scenario
```

Open a Pull Request from your fork's branch against `main`.

---

## License

Apache 2.0 License — see [LICENSE](LICENSE).
