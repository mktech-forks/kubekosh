# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What KubeKosh Is

A self-hosted Kubernetes learning lab. A **single Docker image** runs a real single-node K3s cluster, a Node.js/Express API, and a React SPA with a browser terminal — all behind nginx. Users solve hands-on **task** scenarios (validated against live cluster state) or answer **MCQ** scenarios, organized into **bundles** (Basics, CKA admin, CKAD appdev, CKS security). There is also a timed **exam mode**.

The whole product ships as one container; there is no separate dev server orchestration. Most "development" is editing scenario JSON or the backend/frontend source and rebuilding (or hot-reloading scenarios).

## Common Commands

```bash
# Build the image (single container = whole app)
docker build -t kubekosh .
# multi-platform
docker buildx build --platform linux/amd64,linux/arm64 -t kubekosh .

# Run (requires --privileged for K3s; app at http://localhost:7554)
docker run -itd --name kubekosh --privileged -p 7554:80 kubekosh

# Run with scenario hot-reload mounted (edit JSON locally, no rebuild)
docker run --rm -itd --privileged -p 7554:80 --name kubekosh \
  -v "$PWD/scenarios:/app/scenarios" kubekosh
# then reload the in-memory cache:
curl -X POST http://localhost:7554/api/cache/reload   # or the ↻ button in the UI header

# Persist progress SQLite DB across restarts
docker run -itd --name kubekosh --privileged -p 7554:80 -v <dir>:/data kubekosh

# Frontend dev server (proxies /api to localhost:4000 — needs the backend running)
cd frontend && npm install && npm run dev
cd frontend && npm run build      # outputs to frontend/dist, served by the backend

# Backend (expects a reachable cluster + kubectl; normally runs inside the container)
cd backend && npm install && PROGRESS_DB=./progress.db node server.js
```

There is **no test suite, linter, or CI** in this repo. "Testing" a change means building the image and exercising it in the browser, or hot-reloading scenarios.

## Architecture

### Single-container runtime (`scripts/entrypoint.sh`)
Startup order matters and is sequential: (1) configure cgroupv2 delegation, (2) start `k3s server` (traefik/servicelb disabled, native snapshotter) and wait for the node to be `Ready` and flannel CNI subnet to exist, (3) write kubectl aliases + PS1 into `/root/.bashrc`, (4) start the Node backend on `:4000`, (5) start nginx on `:80`. nginx (`scripts/nginx.conf`) reverse-proxies everything to the Node process: `/api/`, the WebSocket `/shell-ws`, and the static SPA. Host port `7554` → container `80`.

### Backend (`backend/server.js`, single file)
Express REST API + a `node-pty` WebSocket terminal, all in one process on port 4000.

- **Scenario/bundle data** lives as JSON files under `scenarios/data/` and `scenarios/bundles/`, loaded into **in-memory caches** (`scenariosCache`, `bundlesCache`) at startup. Nothing reads disk per-request. Editing JSON requires `POST /api/cache/reload` to take effect.
- **Terminal**: each WS connection on `/shell-ws` spawns a `/bin/bash` PTY with `KUBECONFIG=/root/.kube/config`. Two module-level sets, `activeWsClients` and `activeShells`, track live connections. The server can push text *as terminal output* via `injectToTerminal()` (used by the scenario "context" banner) — this is sent straight to xterm and never enters the shell's stdin; `refreshPrompt()` then writes a bare `\r` to each PTY to repaint the bash prompt.
- **Validation** (`POST /api/scenarios/:id/validate`): runs each `validation.commands[].command` via `kubectl`, compares trimmed stdout to `expected_output` using `checkMatch` (`exact` | `contains` | `not_contains` | `regex`). kubectl API errors (`Error from server…`) are treated as empty output so checks fail cleanly rather than matching stderr noise. All checks must pass to mark `completed`.
- **MCQ** (`POST /api/scenarios/:id/answer`): compares `selected` to `correct_option`.
- **Setup/teardown** (`/setup`, `/teardown`): run a scenario's `setup_commands`/`teardown_commands` as root; non-zero exit codes are tolerated (e.g. "namespace already exists").

### Persistence (SQLite via `better-sqlite3`, `DB_FILE` default `/data/progress.db`)
Three tables, created/migrated on first `getDb()`:
- `progress` — global per-scenario practice progress. New columns are added via a **runtime migration loop** in `getDb()` (`PRAGMA table_info` → `ALTER TABLE` for any missing column). Add new progress columns there, not in the `CREATE TABLE`.
- `sessions` — exam sessions; starting a new one abandons any currently `active` session. On submit, a JSON `snapshot` of per-scenario results is frozen into the row (history is rendered from this snapshot, not live recomputation).
- `exam_progress` — per-session per-scenario status, kept **separate** from global `progress`. Validation/answer endpoints update *both* global progress and, if a session is `active`, `exam_progress`.

### Frontend (`frontend/src`, React + Vite)
`App.jsx` is the single state hub — it owns bundles, scenarios, the selected scenario, global `progress`, and all exam state (`examSession`, `examReport`, `examProgress`). Components under `components/` are presentational and call back into `App` via props (`refreshProgress`, etc.). Key behaviors driven from `App.jsx` effects:
- Selecting a scenario tears down the *previous* scenario's cluster state (`/teardown`) and POSTs `/context` to set the namespace + print the banner in the terminal.
- Exam mode restricts bundle switching to the exam's bundle and hides the terminal for MCQ scenarios.
- The terminal (`Terminal.jsx`) uses `@xterm/xterm` over the `/shell-ws` WebSocket.

## Adding / Editing Scenarios

Scenarios and bundles are the primary content surface. **`scenarios/SCHEMA.md` is authoritative** — read it before adding content. Essentials:
- One JSON file per scenario in `scenarios/data/<id>.json`; one per bundle in `scenarios/bundles/<id>.json`. **Filename must equal the `id` field.**
- Register a new scenario by adding its `id` to the relevant bundle's `scenario_ids` array (order = display order).
- Task scenarios: `validation.commands` must be **idempotent kubectl**; `setup_commands`/`teardown_commands` are kubectl or native Ubuntu commands, each an object `{ "command": "..." }`.
- MCQ scenarios: `correct_option` must match an `options[].id`; always include `explanation`.
- A common pitfall (see recent git history): do not leak the solution into the `description` problem statement.
