# Security Guardrails

- This repository uses `gitleaks` in CI (`.github/workflows/secret-scan.yml`).
- Local pre-commit secret scan is configured at `.githooks/pre-commit`.

Enable local hooks:

```bash
git config core.hooksPath .githooks
```
