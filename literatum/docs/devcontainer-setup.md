# Literatum Worktree Dev Container Setup

## Overview

All literatum worktrees share a **single Docker container** (`lit-wt`). Switching
between worktrees does not require rebuilding or spinning up a new container.
The same container can be used simultaneously from IntelliJ, Cursor, and Zed.

```
~/sourcegit/
├── .devcontainer/          ← shared container config (one for all worktrees)
│   ├── devcontainer.json
│   ├── setup.sh            ← Puppet provisioning (runs once on first build)
│   ├── start-ssh.sh        ← starts sshd on every container boot (for Zed)
│   ├── .bash_aliases       ← shell helpers: cdwt, lswt, cursorwt, etc.
│   └── deployconf.xml
├── lit-2410.code-workspace ← scoped VS Code / Cursor workspace (lit-2410 only)
├── lit-2610.code-workspace ← scoped VS Code / Cursor workspace (lit-2610 only)
└── literatum-worktrees/
    ├── lit-2410/atypon/    ← workspaceFolder default
    ├── lit-2610/atypon/
    └── master/             ← bare git repo (worktree source of truth)
```

---

## How the container works

`devcontainer.json` mounts the **entire `~/sourcegit`** into the container:

```
source: ~/sourcegit  →  target: /home/mbetamony/sourcegit
```

This means every worktree is accessible inside the container at all times.
Adding a new worktree never requires a container rebuild.

The container image is `literatum-base:v2` (or `v3+` once committed after
first provisioning — see "Snapshotting the container" below).

---

## First-time setup (one-time only)

### 1. Open the container in IntelliJ Gateway

- JetBrains Gateway → Dev Containers → point at `~/sourcegit`
- Let Puppet provision the environment (takes a few minutes)
- The `setup.sh` check (`apps64` directory) ensures Puppet never re-runs on rebuild

### 2. Snapshot the provisioned container as a new image

Once provisioned, commit the container so future rebuilds skip Puppet entirely:

```bash
# Get the running container ID
docker ps | grep lit-wt

# Commit (replace <id> with the actual container ID)
docker commit <id> literatum-base:v3
```

Then update `~/sourcegit/.devcontainer/devcontainer.json` — change:
```json
"image": "literatum-base:v2"
```
to:
```json
"image": "literatum-base:v3"
```

Repeat this process whenever you want to snapshot a major environment change
(e.g. after a significant Puppet update): provision once, commit as `v4`, bump the version.

### 3. Cursor one-time setup

The base image has `vscode` baked in as the remote user, but that user was
renamed to `mbetamony`. Cursor reads the image metadata and tries to connect
as `vscode`, which fails. Fix it once:

```bash
mkdir -p ~/Library/Application\ Support/Cursor/User/globalStorage/ms-vscode-remote.remote-containers/nameConfigs

cat > ~/Library/Application\ Support/Cursor/User/globalStorage/ms-vscode-remote.remote-containers/nameConfigs/lit-wt.json << 'EOF'
{
  "remoteUser": "mbetamony",
  "workspaceFolder": "/home/mbetamony/sourcegit/literatum-worktrees/lit-2410/atypon"
}
EOF
```

Also install the `cursor` CLI:
- Cursor → `Cmd+Shift+P` → `Shell Command: Install 'cursor' command in PATH`

---

## Daily workflow — switching worktrees

### IntelliJ
File → Open → paste the worktree path inside the running container:
- `lit-2410` → `/home/mbetamony/sourcegit/literatum-worktrees/lit-2410/atypon`
- `lit-2610` → `/home/mbetamony/sourcegit/literatum-worktrees/lit-2610/atypon`

Opens a new IDE window in the same container. No rebuild.

### Cursor
Use the `cursorwt` script (from your Mac terminal):
```bash
cursorwt lit-2610
cursorwt lit-2410
```
See `scripts/cursorwt` for setup details.

Alternatively via Command Palette:
`Cmd+Shift+P` → `Dev Containers: Attach to Running Container` → `lit-wt`
→ then `File → Open Folder` → paste the path.

### Zed
Connect via SSH to the container's OrbStack IP (stable, doesn't change):
```
ssh://mbetamony@192.168.97.2
```
Then open the worktree folder directly.

> **Note:** Zed's Java LSP (`jdtls`) does not work in this container due to a
> GLIBC version mismatch (container uses an older base). Zed is usable for
> editing, navigation, and non-Java files. Use IntelliJ for Java features.

---

## Adding a new worktree

Use the `createWt` script:
```bash
createWt lit-2610-feature-auth
createWt lit-2610-feature-auth origin/lit-2610   # specify base branch
```

This creates the git worktree and a `.code-workspace` file automatically.
The running container sees the new worktree immediately (no rebuild needed).

---

## Container management

| Task | Command |
|------|---------|
| Check container is running | `docker ps \| grep lit-wt` |
| Start stopped container | `docker start lit-wt` |
| Get container IP (for Zed SSH) | `docker inspect lit-wt --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'` |
| Snapshot current state as new image | `docker commit lit-wt literatum-base:v<n>` |
| Restart SSH server (inside container) | `/home/mbetamony/sourcegit/.devcontainer/start-ssh.sh` |

---

## Mounts reference

| Host path | Container path | Notes |
|-----------|---------------|-------|
| `~/sourcegit` | `/home/mbetamony/sourcegit` | All worktrees, devcontainer config |
| `~/.m2` | `/home/mbetamony/.m2` | Maven cache, shared across worktrees |
| `~/.ssh` | `/home/mbetamony/.ssh` | Read-only, used for git auth |
| `~/sourcegit/literatum-patch-worktrees/master` | `.../lit-2410/atypon/patch` | Patch worktree shortcut for lit-2410 |
| `~/.config/JetBrains` | `/home/mbetamony/.config/JetBrains` | IntelliJ settings — persists SDK/JDK config across rebuilds |
| `~/.cache/JetBrains` | `/home/mbetamony/.cache/JetBrains` | IntelliJ compile-server cache — avoids full reindex on rebuild |

### Why the JetBrains mounts matter

IntelliJ Gateway encodes the **container ID** into SDK paths (e.g. `/$devcontainer.ij/9ab5e3e52bea@.../java`).
Without these mounts, every container rebuild loses the SDK table and compile-server cache,
breaking the debugger and requiring manual JDK reconfiguration.

With the mounts, the config lives on the host and survives container replacement.

If you ever hit `Cannot run program ... (No such file or directory)` in the debugger,
it means IntelliJ cached a stale container ID. Fix it with:
1. `File → Invalidate Caches → Invalidate and Restart`
2. `File → Project Structure → SDKs` → remove stale SDK, re-add `/home/mbetamony/apps64/java17`
