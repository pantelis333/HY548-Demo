# Demo Commands

Run these commands one by one from a WSL terminal.

## Start Everything

1. Go to the project.

```bash
cd /mnt/c/Users/pante/Desktop/HY548_ARGOCD_PROJCECT
```

2. Prepare Docker for k3d on this WSL install. This may ask for your sudo password.

```bash
sudo bash -lc 'service docker stop >/dev/null 2>&1 || true; pkill dockerd >/dev/null 2>&1 || true; pkill containerd >/dev/null 2>&1 || true; sleep 2; if mount | grep -q "cgroup2 on /sys/fs/cgroup "; then for d in rdma pids hugetlb net_prio perf_event net_cls freezer devices memory blkio cpuacct cpu cpuset; do umount /sys/fs/cgroup/$d 2>/dev/null || true; done; umount /sys/fs/cgroup 2>/dev/null || true; mount -t tmpfs -o rw,nosuid,nodev,noexec,relatime cgroup_root /sys/fs/cgroup; for d in cpuset cpu cpuacct blkio memory devices freezer net_cls perf_event net_prio hugetlb pids rdma; do mkdir -p /sys/fs/cgroup/$d; mount -t cgroup -o $d cgroup /sys/fs/cgroup/$d || true; done; [ -f /sys/fs/cgroup/cpuset/cgroup.clone_children ] && echo 1 > /sys/fs/cgroup/cpuset/cgroup.clone_children || true; fi; service docker start'
```

3. Create the k3d cluster, install Argo CD, publish the local Git repo, and deploy `color-showcase`.

```bash
./scripts/setup.sh
```

4. Add and sync the `guestbook-live` app.

```bash
./scripts/add-live-repo-demo.sh
```

5. Start the Argo CD UI port-forward in the background.

```bash
setsid bash -c 'tail -f /dev/null | ./scripts/argocd-port-forward.sh > .demo/argocd-port-forward.log 2>&1' & echo $! > .demo/argocd-port-forward.pid
```

6. Start the guestbook UI port-forward in the background.

```bash
setsid bash -c 'tail -f /dev/null | kubectl -n guestbook-live port-forward --address 0.0.0.0 svc/guestbook-ui 8082:80 > .demo/guestbook-port-forward.log 2>&1' & echo $! > .demo/guestbook-port-forward.pid
```

7. Check that everything is healthy.

```bash
kubectl -n argocd get applications
```

```bash
kubectl -n color-showcase get deploy,pod
```

```bash
kubectl -n guestbook-live get deploy,pod
```

```bash
curl -k -fsS -o /dev/null -w 'Argo CD: %{http_code}\n' https://localhost:8080
```

```bash
curl -fsS -o /dev/null -w 'Color showcase: %{http_code}\n' http://localhost:8081
```

```bash
curl -fsS -o /dev/null -w 'Guestbook: %{http_code}\n' http://localhost:8082
```

Open:

- Argo CD: `https://localhost:8080`
- Color showcase: `http://localhost:8081`
- Guestbook: `http://localhost:8082`

Argo CD login:

- Username: `admin`
- Password: printed by `./scripts/setup.sh`, or run:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

## Stop Everything

1. Go to the project.

```bash
cd /mnt/c/Users/pante/Desktop/HY548_ARGOCD_PROJCECT
```

2. Stop the background port-forwards.

```bash
for f in .demo/argocd-port-forward.pid .demo/guestbook-port-forward.pid; do [ -f "$f" ] && kill -- "-$(cat "$f")" 2>/dev/null || true; done
```

3. Delete the k3d cluster and local Git server container.

```bash
sg docker -c './scripts/teardown.sh'
```

4. Optional: stop Docker too.

```bash
sudo service docker stop
```
