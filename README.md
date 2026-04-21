# HY548 Argo CD Demo

This project creates a local GitOps demo for Argo CD. It runs Kubernetes inside Docker with `k3d`, installs Argo CD into that cluster, then deploys a visual nginx demo app from Git.

Argo CD is a Kubernetes GitOps controller, so a real demo needs Kubernetes. Here, Kubernetes is still "in Docker" because `k3d` runs the cluster nodes as Docker containers.

## What You Get

- A local `k3d` Kubernetes cluster named `argocd-demo`.
- Argo CD installed in the `argocd` namespace.
- A local read-only Git server running as a small Docker image built from `docker/git-server/Dockerfile`.
- An Argo CD `Application` named `color-showcase`.
- A visual web app at `http://localhost:8081`.
- Scripts for theme changes, scaling changes, syncs, status checks, and teardown.

## Prerequisites

You need these tools:

- Docker Desktop or Docker Engine
- Git
- `kubectl`

`./scripts/setup.sh` downloads `k3d` into `.demo/bin` automatically if it is not already installed.

For WSL/Linux, the common install commands are:

```bash
sudo apt-get update
sudo apt-get install -y git curl ca-certificates

# Install k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
```

On Windows, install Docker Desktop first and enable WSL integration for your Linux distro.

## Fresh Computer Setup

Clone or copy this project, then run:

```bash
cd HY548_ARGOCD_PROJCECT
./scripts/setup.sh
```

Open the Argo CD UI in a separate terminal:

```bash
./scripts/argocd-port-forward.sh
```

Then open:

- Argo CD: `https://localhost:8080`
- Demo app: `http://localhost:8081`

If you are opening the browser from Windows and `localhost` does not work, use the WSL IP printed by `./scripts/argocd-port-forward.sh`. You can also print it with:

```bash
hostname -I | awk '{print $1}'
```

The username is `admin`. The password is printed by `setup.sh` and `argocd-port-forward.sh`.

The browser will warn about the Argo CD certificate because the local install uses a self-signed certificate. Continue through the warning for the demo.

## Best Demo Flow

### 1. Show GitOps From Zero

If you want the audience to see the first sync happen live, recreate the cluster with initial sync disabled:

```bash
./scripts/teardown.sh
RUN_INITIAL_SYNC=false ./scripts/setup.sh
./scripts/argocd-port-forward.sh
```

Open `https://localhost:8080`, click the `color-showcase` app, show that it is `OutOfSync`, then click `Sync`.

### 2. Show A Visual Git Change

Change the app theme in Git and publish it to the local Docker-served Git repo:

```bash
./scripts/set-theme.sh ocean
```

In Argo CD:

1. Open `color-showcase`.
2. Show the diff.
3. Click `Sync`.
4. Refresh `http://localhost:8081` and show the new theme.

Other themes:

```bash
./scripts/set-theme.sh ember
./scripts/set-theme.sh contrast
./scripts/set-theme.sh aurora
```

### 3. Show Kubernetes Scaling Through Git

Change the desired replica count in Git:

```bash
./scripts/set-replicas.sh 4
```

In Argo CD, show the diff and sync. The resource tree should update from 2 pods to 4 pods.

You can also sync from the terminal:

```bash
./scripts/sync-app.sh
./scripts/status.sh
```

### 4. Show Drift Repair

Manually change the live cluster, outside Git:

```bash
kubectl -n color-showcase scale deployment color-showcase --replicas=1
```

Argo CD will detect that live state does not match Git. Open the app and show the difference, then click `Sync` or run:

```bash
./scripts/sync-app.sh
```

For an automatic self-heal version of the same demo:

```bash
kubectl -n argocd patch application color-showcase --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true},"syncOptions":["CreateNamespace=true"]}}}'

kubectl -n color-showcase scale deployment color-showcase --replicas=1
watch kubectl -n color-showcase get deployment color-showcase
```

### 5. Show Rollback History

Make two theme changes and sync both:

```bash
./scripts/set-theme.sh ocean
./scripts/sync-app.sh
./scripts/set-theme.sh ember
./scripts/sync-app.sh
```

In Argo CD, open the app history and show that Argo CD knows which Git revisions were deployed.

### 6. Show A Live Public GitHub Repo

Deploy the official Argo CD example guestbook app directly from GitHub:

```bash
./scripts/add-live-repo-demo.sh
```

In Argo CD, you should now see a second app named `guestbook-live`. It uses the official GitHub guestbook app plus a local extras source that scales the frontend and adds demo backend services, so the resource tree is more interesting to present.

## Useful Commands

```bash
# Create cluster, install Argo CD, publish local Git repo, deploy demo app
./scripts/setup.sh

# Print Argo CD password and keep the UI port-forward open
./scripts/argocd-port-forward.sh

# Request an Argo CD sync
./scripts/sync-app.sh

# Publish current local Git changes to the local demo Git server
./scripts/publish-local-git.sh "My demo change"

# Show Argo CD app and Kubernetes workload status
./scripts/status.sh

# Delete the local cluster and Docker Git server
./scripts/teardown.sh
```

## Optional GitHub Mode

By default, the demo is self-contained and uses a local Git repo served by Docker. If you want Argo CD to read from GitHub instead:

```bash
git remote add origin https://github.com/<your-user>/<your-repo>.git
git push -u origin main

REPO_URL=https://github.com/<your-user>/<your-repo>.git ./scripts/setup.sh
```

If your default branch is not `main`, set `TARGET_REVISION`:

```bash
REPO_URL=https://github.com/<your-user>/<your-repo>.git TARGET_REVISION=master ./scripts/setup.sh
```

## Ports And Settings

Defaults:

- Argo CD UI port-forward: `https://localhost:8080`
- Demo app: `http://localhost:8081`
- k3d cluster: `argocd-demo`
- Kubernetes API port: `6550`

Override examples:

```bash
HOST_APP_PORT=8090 ./scripts/setup.sh
ARGOCD_UI_PORT=8091 ./scripts/argocd-port-forward.sh
CLUSTER_NAME=my-demo ./scripts/setup.sh
```

## Troubleshooting

If Docker is not running:

```bash
docker info
```

If Docker says `permission denied` in WSL, either enable Docker Desktop WSL integration for your distro or use a Linux Docker Engine setup where your user can access the Docker socket.

If port `8081` is already used:

```bash
HOST_APP_PORT=8090 ./scripts/setup.sh
```

If port `8080` is already used:

```bash
ARGOCD_UI_PORT=8091 ./scripts/argocd-port-forward.sh
```

If the app does not update after a Git change:

```bash
./scripts/publish-local-git.sh "Refresh demo"
./scripts/sync-app.sh
```

If you want to start over:

```bash
./scripts/teardown.sh
./scripts/setup.sh
```

## Project Layout

```text
argocd/applications/                 Argo CD Application template
k8s/color-showcase/                  Kustomize app deployed by Argo CD
k8s/color-showcase/site/             Static visual demo app
scripts/setup.sh                     Full local setup
scripts/argocd-port-forward.sh       Opens Argo CD UI access
scripts/set-theme.sh                 Creates a visible Git change
scripts/set-replicas.sh              Creates a scaling Git change
scripts/add-live-repo-demo.sh        Adds the official public GitHub guestbook demo
scripts/sync-app.sh                  Triggers Argo CD sync
scripts/status.sh                    Shows current status
scripts/teardown.sh                  Deletes local demo resources
docker/git-server/Dockerfile         Local Git daemon image used by Argo CD
```

## References

- Argo CD getting started: https://argo-cd.readthedocs.io/en/latest/getting_started/
- Argo CD installation manifests: https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/
- k3d exposing services: https://k3d.io/v5.4.6/usage/exposing_services/
