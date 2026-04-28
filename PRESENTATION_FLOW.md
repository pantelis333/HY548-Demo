# Presentation Flow

Use this as the live script. Keep one terminal open in this project folder.

## Browser Tabs

Open these before you start speaking:

1. Terminal in this folder:
   ```bash
   cd /mnt/c/Users/pante/Desktop/HY548_ARGOCD_PROJCECT
   ```
2. Argo CD: `https://localhost:8080`
3. GitHub repo: `https://github.com/pantelis333/HY548-Demo`
4. Color app: `http://localhost:8081`
5. Guestbook app: `http://localhost:8082`
6. GitHub source demo: `http://localhost:8083`

## 1. Start The Demo

Run:

```bash
make start
```

If sudo asks for a password, enter your local sudo password. `make start` prints the Argo CD admin password.

Say:

> This is a local Kubernetes cluster running with k3d. Argo CD is installed in the cluster and all the demo applications are declared in one GitHub repository: HY548-Demo.

Show:

- Argo CD tab.
- Log in with username `admin` and the password printed by `make start`.
- Click **REFRESH APPS** if the page was already open.

Say:

> Argo CD is not deploying random live changes. It is reading desired state from Git. The three tiles here are three Argo CD Applications, all sourced from the same GitHub repo.

Point at:

- `color-showcase`
- `guestbook-live`
- `github-source-demo`

Show the repo field on the tiles:

> Notice that all three applications point to `https://github.com/pantelis333/HY548-Demo.git` on branch `main`.

## 2. Stage 0 Baseline

Show:

- Argo CD application list.
- All apps should be `Synced` and `Healthy`.
- Color app tab at `http://localhost:8081`.
- GitHub source demo tab at `http://localhost:8083`.

Say:

> This is stage 0. It is the clean baseline. The repo, Argo CD, and Kubernetes all agree. I can rerun the demo from this same state every time.

Optional check:

```bash
make status
make check-urls
```

## 3. Demo 1: color-showcase

Run:

```bash
make demo1
```

Say while it runs:

> Demo 1 is dedicated to the color-showcase application. The command creates a Git commit that changes only the color-showcase manifests. Argo CD then syncs that application into Kubernetes.

Show:

1. GitHub repo tab.
2. Open the newest commit named `Demo 1 color-showcase scale`.
3. Show that the changed files are under `k8s/color-showcase/`.

Say:

> The commit changes desired state in Git: the page configuration and the replica count. Git is now ahead of the cluster, and Argo CD applies that desired state.

Show:

1. Argo CD tab.
2. Open `color-showcase`.
3. Show the resource tree and pods.
4. Refresh `http://localhost:8081`.

Say:

> After sync, Kubernetes matches Git. The color-showcase app has scaled up and the visible page changed. This is the basic GitOps loop: commit, compare, sync, converge.

## 4. Demo 2: guestbook-live

Run:

```bash
make demo2
```

Say while it runs:

> Demo 2 is dedicated to the guestbook-live application. This commit does not change color-showcase. It changes the guestbook topology: UI pods, API pods, cache pods, and Redis followers.

Show:

1. GitHub repo tab.
2. Open the newest commit named `Demo 2 guestbook topology scale`.
3. Show that the changed files are under `k8s/guestbook-live-enhanced/`.

Say:

> This is a bigger Kubernetes change, but it is still just a Git commit. Argo CD reads the same repo and applies only the guestbook application path.

Show:

1. Argo CD tab.
2. Open `guestbook-live`.
3. Show the resource tree with more pods.
4. Show `http://localhost:8082` if you want to show the live guestbook page.

Say:

> The important part is the resource graph. The application got more replicas and a more interesting topology without manually editing Kubernetes.

## 5. Demo 3: github-source-demo

Run:

```bash
make demo3
```

Say while it runs:

> Demo 3 is dedicated to the github-source-demo application. This tile exists to make the GitHub source visible as a real Argo CD application. In this step, the application itself becomes more complex.

Show:

1. GitHub repo tab.
2. Open the newest commit named `Demo 3 github-source-demo flow`.
3. Show that the changed files are under `k8s/github-source-demo/`.

Say:

> This commit changes only the source-demo app. It expands the page and adds extra Kubernetes resources, so the Argo CD graph becomes more visual.

Show:

1. Argo CD tab.
2. Open `github-source-demo`.
3. Show the expanded graph.
4. Point out the extra deployments/services:
   - `repo-webhook`
   - `commit-renderer`
   - `sync-auditor`
   - `github-flow-notes`
5. Refresh `http://localhost:8083`.

Say:

> The visual graph now represents the GitOps flow: GitHub commit, Argo comparison, rendering, syncing, and audit. Again, this came from a Git commit, not from manual cluster changes.

## 6. Wrap Up

Show:

- Argo CD application list.
- All three apps should be `Synced` and `Healthy`.
- GitHub commit history.

Say:

> The whole demo used one GitHub repository as the source of truth. Each application watches a different path in the same repo. Each demo step created a commit, Argo CD detected the desired state, and Kubernetes converged to it.

## 7. Reset And Stop

Run:

```bash
make stop
```

Say:

> Stop also resets everything back to stage 0 before shutting down. That means the next run starts from the same baseline and the presentation is repeatable.

If you want to stop Docker too:

```bash
sudo service docker stop
```

## Emergency Commands

If something looks stale in Argo CD:

```bash
make stage0
make check-urls
```

If you only need the password:

```bash
make password
```

If a page does not refresh immediately, wait a few seconds and refresh again. The demo commands wait for Argo sync and Kubernetes rollout, but the browser may still cache the previous page briefly.
