SHELL := bash

PROJECT_ROOT := $(CURDIR)
LOCAL_BIN := $(PROJECT_ROOT)/.demo/bin
K3D_CLUSTER := argocd-demo
LOCAL_GIT_CONTAINER := argocd-demo-git

.PHONY: start stop status password demo-theme demo-color-pods demo-guestbook-ui-pods demo-guestbook-api-pods demo-guestbook-cache-pods demo-guestbook-redis-pods sync-color sync-guestbook

start:
	@mkdir -p .demo
	@test -x "$(LOCAL_BIN)/k3d" || { echo "Missing $(LOCAL_BIN)/k3d. Run ./scripts/setup.sh once first."; exit 1; }
	@for f in .demo/argocd-port-forward.pid .demo/guestbook-port-forward.pid; do [ -f "$$f" ] && kill -- "-$$(cat "$$f")" 2>/dev/null || true; done
	@sudo service docker start
	@sg docker -c 'PATH="$(LOCAL_BIN):$$PATH" k3d cluster start "$(K3D_CLUSTER)"'
	@sg docker -c 'docker start "$(LOCAL_GIT_CONTAINER)" >/dev/null 2>&1 || true'
	@kubectl config use-context "k3d-$(K3D_CLUSTER)" >/dev/null
	@setsid bash -lc 'tail -f /dev/null | ./scripts/argocd-port-forward.sh > .demo/argocd-port-forward.log 2>&1' & echo $$! > .demo/argocd-port-forward.pid
	@setsid bash -lc 'tail -f /dev/null | kubectl -n guestbook-live port-forward --address 0.0.0.0 svc/guestbook-ui 8082:80 > .demo/guestbook-port-forward.log 2>&1' & echo $$! > .demo/guestbook-port-forward.pid
	@echo "Argo CD password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
	@echo "Argo CD: https://localhost:8080"
	@echo "Color showcase: http://localhost:8081"
	@echo "Guestbook: http://localhost:8082"

stop:
	@test -x "$(LOCAL_BIN)/k3d" || { echo "Missing $(LOCAL_BIN)/k3d. Run ./scripts/setup.sh once first."; exit 1; }
	@for f in .demo/argocd-port-forward.pid .demo/guestbook-port-forward.pid; do [ -f "$$f" ] && kill -- "-$$(cat "$$f")" 2>/dev/null || true; done
	@sg docker -c 'docker stop "$(LOCAL_GIT_CONTAINER)" >/dev/null 2>&1 || true'
	@sg docker -c 'PATH="$(LOCAL_BIN):$$PATH" k3d cluster stop "$(K3D_CLUSTER)"'

status:
	@kubectl -n argocd get applications
	@echo
	@kubectl -n color-showcase get deploy,pod
	@echo
	@kubectl -n guestbook-live get deploy,pod

password:
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

demo-theme:
	@test -n "$(THEME)" || { echo "Usage: make demo-theme THEME=aurora|ocean|ember|contrast"; exit 1; }
	@./scripts/set-theme.sh "$(THEME)"

demo-color-pods:
	@test -n "$(REPLICAS)" || { echo "Usage: make demo-color-pods REPLICAS=4"; exit 1; }
	@./scripts/set-replicas.sh "$(REPLICAS)"

demo-guestbook-ui-pods:
	@test -n "$(REPLICAS)" || { echo "Usage: make demo-guestbook-ui-pods REPLICAS=8"; exit 1; }
	@./scripts/set-guestbook-replicas.sh ui "$(REPLICAS)"

demo-guestbook-api-pods:
	@test -n "$(REPLICAS)" || { echo "Usage: make demo-guestbook-api-pods REPLICAS=3"; exit 1; }
	@./scripts/set-guestbook-replicas.sh api "$(REPLICAS)"

demo-guestbook-cache-pods:
	@test -n "$(REPLICAS)" || { echo "Usage: make demo-guestbook-cache-pods REPLICAS=3"; exit 1; }
	@./scripts/set-guestbook-replicas.sh cache "$(REPLICAS)"

demo-guestbook-redis-pods:
	@test -n "$(REPLICAS)" || { echo "Usage: make demo-guestbook-redis-pods REPLICAS=3"; exit 1; }
	@./scripts/set-guestbook-replicas.sh redis-follower "$(REPLICAS)"

sync-color:
	@APP_NAME=color-showcase ./scripts/sync-app.sh

sync-guestbook:
	@APP_NAME=guestbook-live ./scripts/sync-app.sh
