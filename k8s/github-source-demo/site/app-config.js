window.SOURCE_DEMO_CONFIG = {
  stage: "Demo 3",
  headline: "GitHub source flow expanded",
  message: "This commit is dedicated to the github-source-demo app. Its Argo CD resource graph grows with webhook, renderer, auditor, services, pods, and a ConfigMap.",
  repo: "github.com/pantelis333/HY548-Demo",
  branch: "main",
  appName: "github-source-demo",
  change: "source flow expanded",
  accent: "#e5e7eb",
  accentTwo: "#22c55e",
  mode: "expanded",
  steps: [
    { label: "GitHub", value: "HY548-Demo", note: "commit pushed" },
    { label: "Webhook", value: "repo-webhook", note: "2 pods" },
    { label: "Argo CD", value: "compare", note: "desired vs live" },
    { label: "Renderer", value: "commit-renderer", note: "2 pods" },
    { label: "Auditor", value: "sync-auditor", note: "1 pod" }
  ]
};
