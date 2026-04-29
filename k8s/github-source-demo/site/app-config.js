window.SOURCE_DEMO_CONFIG = {
  stage: "Stage 0",
  headline: "HY548-Demo on GitHub",
  message: "This third Argo CD application makes the GitHub source visible as its own tile next to color-showcase and guestbook-live.",
  repo: "github.com/pantelis333/HY548-Demo",
  branch: "main",
  appName: "github-source-demo",
  change: "baseline",
  accent: "#22d3ee",
  accentTwo: "#facc15",
  mode: "baseline",
  steps: [
    { label: "GitHub", value: "HY548-Demo", note: "main branch" },
    { label: "Argo CD", value: "source tile", note: "tracks the repo" },
    { label: "Kubernetes", value: "1 pod", note: "baseline state" }
  ]
};
