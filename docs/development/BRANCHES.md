# Branch and milestone policy

- `main`: published, platform-validated baseline. Fast-forward only after the milestone gates pass.
- `develop`: current integration work. Each coherent validated milestone gets a GitHub prerelease and an updated fixed Web deployment; do not batch all phases into one final delivery.
- Short-lived topic branches: create only for independent work; remove after landing. Never force-push shared history.
- Frozen/unmerged historical work is retained under annotated `archive/2026-10-28/*` tags: `dsr-open-commit`, `web33-optical-research`, `p2-cn-priority-prototype`, `web33-failed`. These tags are preservation, not acceptance. The failed Web33 code is not merged into this release.
- A verified Git bundle and branch inventory preserve the pre-cleanup refs. Four dirty historical local worktrees retain all files and their own `archive/local-*` branches; they were neither reset nor deleted. Remote branches are `main` and `develop`.

A development push, source assertion count, extracted-resource count, or native source screenshot does not alone satisfy the Web release gate. Release notes must state the accepted subset and remaining limitations. Keep the previous deployment and activate new immutable assets atomically; verify fixed HTTPS after activation.
