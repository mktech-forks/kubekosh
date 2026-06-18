# KubeKosh Configuration Schema Reference

KubeKosh is a multi-subject learning platform. Content is a three-level hierarchy — **Subject → Bundle → Scenario** — defined across three directories:
1. **Subjects (`scenarios/subjects`)**: Each file defines one top-level subject (e.g., Kubernetes, Linux), including its branding and — crucially — the **execution environment** its scenarios run in.
2. **Bundles (`scenarios/bundles`)**: Each file defines one study bundle within a subject (e.g., CKA, CKAD, CKS), including exam duration and the ordered list of included scenarios.
3. **Scenarios (`scenarios/data`)**: Each file defines one individual exercise — a reading lesson, a hands-on task, or a multiple-choice question (MCQ).

> **Backward compatibility:** A bundle with no `subject` field defaults to `kubernetes`, and a scenario inherits its subject (and therefore its execution environment) from the bundle that lists it. Existing Kubernetes content needs no edits.

---

## 1. Subjects Schema (`scenarios/subjects`)

Each file contains a **single subject object**. The filename must match the subject's `id` field (e.g., `linux.json`). The subjects directory is optional — when absent, a default `kubernetes` subject is synthesized so legacy layouts still boot.

### Schema Fields
* **`id`** *(string, required)*: A unique, kebab-case identifier for the subject (e.g., `linux`).
* **`name`** *(string, required)*: Human-readable name shown in the subject nav (e.g., `Linux`).
* **`icon`** *(string, required)*: An emoji or glyph (e.g., `🐧`).
* **`tagline`** *(string, required)*: Short summary; also used as the header sub-brand when the subject is active.
* **`color`** / **`colorDim`** *(string, required)*: Accent hex color and its translucent RGBA variant, for UI highlighting.
* **`environment`** *(string, required)*: The runtime its scenarios run in. Determines how the terminal context, setup/teardown/validate commands, validation error handling, and the health probe behave. Supported values:
  * **`k8s`** — runs against the in-container K3s cluster. `/context` sets the active `kubectl` namespace; validation suppresses `kubectl` "Error from server…" stderr; the header shows a readiness badge.
  * **`bash`** — a plain shell. No cluster, no namespace; stderr is treated as legitimate command output; no readiness badge.
  * **`docker`** — commands talk to an in-container Docker daemon (docker-in-docker, started by `scripts/env-init/docker.sh`). No namespace; stderr is treated as legitimate output (assert validations on stdout); the health probe runs `docker info`.
* **`readyLabel`** *(string, optional)*: Text for the header readiness badge (e.g. `Cluster Ready`, `Docker Ready`). Omit for `bash`-style subjects that have no backing runtime — the badge is then hidden.
* **`bundle_order`** *(array of strings, optional)*: Bundle IDs in display order; falls back to file order.

### Example Subject
```json
{
  "id": "linux",
  "name": "Linux",
  "icon": "🐧",
  "tagline": "Hands-on Linux Command Line",
  "color": "#f0b429",
  "colorDim": "rgba(240,180,41,0.12)",
  "environment": "bash",
  "bundle_order": ["linux-basics"]
}
```

> **Adding a new environment** (e.g. Docker, cloud CLIs): add an entry to the `ENVIRONMENTS` map in `backend/server.js` and, if the runtime needs provisioning, drop a `scripts/env-init/<env>.sh` script (launched in the background at startup). No endpoint changes are required.

---

## 2. Bundles Schema (`scenarios/bundles`)

Each file contains a **single bundle object**. The filename must match the bundle's `id` field (e.g., `k8s-basics.json`).

### Schema Fields
* **`id`** *(string, required)*: A unique, kebab-case identifier for the bundle (e.g., `k8s-basics`).
* **`subject`** *(string, optional)*: The owning subject's `id` (e.g., `linux`). Defaults to `kubernetes` when omitted.
* **`name`** *(string, required)*: The human-readable name of the bundle shown in navigation (e.g., `Kubernetes Basics`).
* **`icon`** *(string, required)*: An emoji or glyph representing the bundle (e.g., `🌱`).
* **`tagline`** *(string, required)*: A short summary of the bundle's objectives.
* **`color`** *(string, required)*: Hex color code representing the bundle's UI identity/accent color (e.g., `#3fb950`).
* **`colorDim`** *(string, required)*: Translucent RGBA color matching the accent color at low opacity, used for UI row highlighting (e.g., `rgba(63,185,80,0.12)`).
* **`exam_minutes`** *(number, required)*: The time limit allocated for the mock exam in minutes (e.g., `60`).
* **`scenario_ids`** *(array of strings, required)*: List of scenario IDs belonging to this bundle in the order they should appear.

### Example Bundle
```json
{
  "id": "linux-basics",
  "subject": "linux",
  "name": "Linux Basics",
  "icon": "🐧",
  "tagline": "Files, permissions and the shell",
  "color": "#f0b429",
  "colorDim": "rgba(240,180,41,0.12)",
  "exam_minutes": 30,
  "scenario_ids": [
    "linux-intro-lesson",
    "linux-permissions-mcq",
    "linux-create-file-task"
  ]
}
```

---

## 3. Scenarios Schema (`scenarios/data`)

Each file contains a **single scenario object**. The filename must match the scenario's `id` field (e.g., `k8s-basics.json`).

Scenarios are defined as JSON objects. A scenario can be a reading lesson (`"lesson"`), a hands-on console challenge (`"task"`), or a multiple-choice question (`"mcq"`).

### Common Fields (All Types)
```jsonc
{
  "id": "unique-kebab-case-id",        // string — unique scenario identifier
  "title": "Human-readable Title",      // string — shown in sidebar list
  "category": "Workloads",             // string — groups scenarios in sidebar accordion
  "difficulty": "Easy",                // "Easy" | "Medium" | "Hard"
  "type": "task",                      // "lesson" | "task" | "mcq"
  "weight": 7,                         // number — points value (used for final grade scoring)
  "description": "## Markdown...",     // string — problem statement supporting GitHub-flavored Markdown
  "hints": [...],                      // array — see Hints schema below
  "setup_commands": [...],             // array<object> — commands run on environment preparation
  "teardown_commands": [...],           // array<object> — optional — cleanup commands run after scenario completes
  "default_namespace": "default"       // string — optional — default active namespace for the terminal
}
```

---

### Hints Schema
Each hint is rendered as a collapsible card inside the Hints tab of the UI:
```jsonc
{
  "title": "Short title for the hint card",
  "body":  "Explanation text (plain text, no markdown format).",
  "command": "kubectl run nginx --image=nginx" // optional — renders a copyable code block
}
```

---

### Setup & Teardown Commands
* **`setup_commands`**: Executed sequentially in the scenario's execution environment when the user starts a scenario or clicks **"Prepare Environment"**. For `k8s` subjects these are typically `kubectl` commands (pre-deploying resources or injecting bugs); for `bash` subjects they are plain shell commands. Useful for resetting state before an exercise.
* **`teardown_commands`**: Optional cleanup commands run when moving away from or resetting a scenario.
* Commands must be **objects** with a `command` key:
  ```jsonc
  "setup_commands": [
    { "command": "kubectl create namespace debug" },
    { "command": "kubectl create deployment broken-app --image=nginx:1.25 -n debug" }
  ]
  ```
* *Note:* Non-zero exit codes are tolerated (e.g., "namespace already exists" errors won't halt the pipeline). All commands execute as `root`.

---

### Type: `"lesson"` — Reading Lesson
Renders a markdown reading page only — no terminal, no hints tab, no validation. The user clicks **Mark as Complete** to finish it. A lesson counts toward bundle/exam progress by its `weight` like any other scenario. Omit `validation`, `options`, and `setup_commands` (give it a small `weight`, e.g. `1`).

```jsonc
{
  "type": "lesson",
  "weight": 1,
  "description": "## Navigating the Filesystem\n\nEverything in Linux lives under `/` …"
}
```

---

### Type: `"task"` — Hands-On Scenario
Requires the user to run commands in the interactive terminal. The system runs an automated validation sequence to check the resulting state (cluster state for `k8s` subjects, filesystem/process state for `bash` subjects).

```jsonc
{
  "type": "task",
  "validation": {
    "description": "Check that deployment has been correctly configured",
    "commands": [
      {
        "description": "Checks the running pods count",
        "command": "kubectl get deploy nginx -o jsonpath='{.status.readyReplicas}'",
        "expected_output": "3",
        "match": "exact" // "exact" | "contains" | "regex"
      }
    ]
  }
}
```

#### Match Modes
| Mode | Behaviour |
| :--- | :--- |
| `exact` | Trimmed stdout must exactly equal `expected_output`. |
| `contains` | stdout must contain `expected_output` as a substring. |
| `not_contains` | stdout must **not** contain `expected_output` as a substring. |
| `regex` | stdout must match the regular expression in `expected_output`. |

> **Validating against stdout:** For `bash` subjects, a command's **stderr is treated as legitimate output** and is included in the value matched against `expected_output` (only `k8s` subjects suppress `kubectl` API errors). Write validation commands that print the signal you want to `stdout` — e.g. `test -f /root/hello.txt && echo yes` (match `exact` `yes`) rather than relying on exit codes.

---

### Type: `"mcq"` — Multiple Choice Question
Renders a questionnaire block. No terminal is shown. The user answers by selecting an option.

```jsonc
{
  "type": "mcq",
  "options": [
    { "id": "a", "text": "Option A explanation" },
    { "id": "b", "text": "Option B explanation" },
    { "id": "c", "text": "Option C explanation" },
    { "id": "d", "text": "Option D explanation" }
  ],
  "correct_option": "c",               // must match one of the option IDs
  "explanation": "Detailed explanation of why C is the correct answer." // shown after submitting
}
```

---

## 3. Full Examples

### Full Example — Hands-On Task Scenario
```json
{
  "id": "scale-deployment",
  "title": "Scale a Deployment",
  "category": "Workloads",
  "difficulty": "Easy",
  "type": "task",
  "weight": 4,
  "description": "## Scale the Deployment\n\nA deployment named `myapp` exists in the `default` namespace.\n\n**Scale it to 5 replicas.**",
  "hints": [
    {
      "title": "Using kubectl scale",
      "body": "The scale subcommand lets you change the replica count imperatively.",
      "command": "kubectl scale deployment myapp --replicas=5"
    }
  ],
  "setup_commands": [
    { "command": "kubectl create deployment myapp --image=nginx:1.25 --replicas=1" }
  ],
  "teardown_commands": [
    { "command": "kubectl delete deployment myapp --ignore-not-found" }
  ],
  "default_namespace": "default",
  "validation": {
    "description": "Checks that myapp has 5 ready replicas.",
    "commands": [
      {
        "description": "myapp has 5 ready replicas",
        "command": "kubectl get deployment myapp -o jsonpath='{.status.readyReplicas}'",
        "expected_output": "5",
        "match": "exact"
      }
    ]
  }
}
```

### Full Example — MCQ Scenario
```json
{
  "id": "service-types-mcq",
  "title": "Kubernetes Service Types",
  "category": "Networking",
  "difficulty": "Easy",
  "type": "mcq",
  "weight": 3,
  "description": "## Kubernetes Service Types\n\nWhich `kubectl` command creates a ClusterIP service named `my-svc` exposing port 80 for a deployment named `my-app`?",
  "options": [
    { "id": "a", "text": "kubectl expose deployment my-app --name=my-svc --port=80 --type=ClusterIP" },
    { "id": "b", "text": "kubectl create service my-svc --port=80" },
    { "id": "c", "text": "kubectl apply service my-app --port=80" },
    { "id": "d", "text": "kubectl expose pod my-app --name=my-svc --port=80 --type=NodePort" }
  ],
  "correct_option": "a",
  "explanation": "`kubectl expose deployment` is the correct imperative command. It creates a Service targeting the deployment's pods. `--type=ClusterIP` is the default but explicit here for clarity.",
  "hints": [
    {
      "title": "kubectl expose syntax",
      "body": "Use kubectl expose to create a Service from an existing resource. Specify the resource type, name, port, and service type.",
      "command": "kubectl expose deployment my-app --name=my-svc --port=80 --type=ClusterIP"
    }
  ],
  "setup_commands": [],
  "teardown_commands": [],
  "default_namespace": "default"
}
```
