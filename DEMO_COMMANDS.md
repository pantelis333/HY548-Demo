# Turn Demo On And Off

These commands use the setup that already exists. They do not recreate the cluster, reinstall Argo CD, or delete demo data.

## Quick Start

Preferred commands:

```bash
make start
```

`make start` prints the Argo CD password when it finishes.

```bash
make status
```

```bash
make check-urls
```

```bash
make stop
```

## Turn On

Run these one by one.

```bash
cd /mnt/c/Users/pante/Desktop/HY548_ARGOCD_PROJCECT
```

```bash
sudo bash -lc 'service docker start'
```

```bash
sg docker -c 'PATH="$PWD/.demo/bin:$PATH" k3d cluster start argocd-demo'
```

```bash
sg docker -c 'docker start argocd-demo-git >/dev/null 2>&1 || true'
```

```bash
kubectl config use-context k3d-argocd-demo
```

```bash
setsid bash -lc 'exec ./scripts/argocd-port-forward.sh' > .demo/argocd-port-forward.log 2>&1 & echo $! > .demo/argocd-port-forward.pid
```

```bash
setsid bash -lc 'exec kubectl -n color-showcase port-forward --address 0.0.0.0 svc/color-showcase 8081:80' > .demo/color-port-forward.log 2>&1 & echo $! > .demo/color-port-forward.pid
```

```bash
setsid bash -lc 'exec kubectl -n guestbook-live port-forward --address 0.0.0.0 svc/guestbook-ui 8082:80' > .demo/guestbook-port-forward.log 2>&1 & echo $! > .demo/guestbook-port-forward.pid
```

```bash
for port in 8080 8081 8082; do for i in $(seq 1 30); do (: >/dev/tcp/127.0.0.1/$port) >/dev/null 2>&1 && break; sleep 1; if [ "$i" = 30 ]; then echo "Timed out waiting for port $port"; exit 1; fi; done; done
```

Check status:

```bash
kubectl -n argocd get applications
```

```bash
kubectl -n color-showcase get deploy,pod
```

```bash
kubectl -n guestbook-live get deploy,pod
```

Check URLs:

```bash
make check-urls
```

Open:

- Argo CD: `https://localhost:8080`
- Color showcase: `http://localhost:8081`
- Guestbook: `http://localhost:8082`

Argo CD password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

## Demo Commands

Use these after `make start`.

Change the color-showcase theme in Git:

```bash
make demo-theme THEME=ocean
```

Change the color-showcase replica count in Git:

```bash
make demo-color-pods REPLICAS=4
```

Change guestbook UI replicas in Git:

```bash
make demo-guestbook-ui-pods REPLICAS=8
```

Change guestbook API replicas in Git:

```bash
make demo-guestbook-api-pods REPLICAS=3
```

Change guestbook cache replicas in Git:

```bash
make demo-guestbook-cache-pods REPLICAS=3
```

Change guestbook Redis follower replicas in Git:

```bash
make demo-guestbook-redis-pods REPLICAS=3
```

Sync from the terminal if you do not want to click Sync in Argo CD:

```bash
make sync-color
```

```bash
make sync-guestbook
```

Show current demo status:

```bash
make status
```

## Turn Off

Run these one by one. This stops the demo but keeps the cluster and data so you can start it again later.

```bash
cd /mnt/c/Users/pante/Desktop/HY548_ARGOCD_PROJCECT
```

```bash
for f in .demo/argocd-port-forward.pid .demo/color-port-forward.pid .demo/guestbook-port-forward.pid; do if [ -f "$f" ]; then pid="$(cat "$f")"; kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true; rm -f "$f"; fi; done
```

```bash
sg docker -c 'docker stop argocd-demo-git >/dev/null 2>&1 || true'
```

```bash
sg docker -c 'PATH="$PWD/.demo/bin:$PATH" k3d cluster stop argocd-demo'
```

Optional, if you also want Docker itself stopped:

```bash
sudo service docker stop
```

## Full Reset

Only use this if you want to delete the cluster and rebuild from scratch later.

```bash
sg docker -c './scripts/teardown.sh'
```
