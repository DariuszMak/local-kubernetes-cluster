# Local kubernetes cluster

## Requirements

- [UV](https://github.com/astral-sh/uv) package manager
- [Docker Desktop](https://docs.docker.com/desktop/install/windows-install/)
- [Vault](https://developer.hashicorp.com/vault/install)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [Helm](https://helm.sh/docs/intro/install/)
- [Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)
- [Task](https://taskfile.dev/installation/)
- [Tilt](https://docs.tilt.dev/install.html)


## Local development (Windows PowerShell):

You can also use VSCode `settings.json` and `launch.json` files to run the project (choose interpreter created by UV).

## Fast native Windows development:

```commandline
```



# Vault Integration

HashiCorp Vault is used to manage secrets locally and in Kubernetes, replacing
plain `.dev.env` secret injection. Everything runs fully locally — no cloud,
no external Vault server.

---

## Architecture overview

```
┌─────────────────────────────────────────────────────────────────┐
│  LOCAL WINDOWS DEV                                              │
│                                                                 │
│  vault server -dev  ──►  task vault-render  ──►  .vault-secrets.env  ──►  src/main.py │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  k3d / KUBERNETES                                               │
│                                                                 │
│  vault pod (dev mode)                                           │
│       │                                                         │
│       └──► Vault Agent Injector sidecar                        │
│                   │                                             │
│                   └──► /vault/secrets/app.env  ──►  container  │
└─────────────────────────────────────────────────────────────────┘
```

Secret loading priority in `src/main.py`:

1. `VAULT_SECRETS_FILE` env var → file written by Vault Agent sidecar (k8s)
2. `.vault-secrets.env` → rendered by `vault-render-env.ps1` (Windows native)
3. `.dev.env` → plain fallback (no Vault available / CI)

---

## Quick start

### Native Windows development

```powershell
# 1. Start Vault dev server and seed secrets from .dev.env
task vault-dev

# 2. Render secrets to .vault-secrets.env
task vault-render

# 3. Run the app — it picks up .vault-secrets.env automatically
task local-dev-windows-run

# Or do all three in one go:
task local-dev-windows-run-vault
```

### Full flow with k3d

```powershell
# After `task k3d` has the cluster running:
task vault-k3d       # Installs Vault in k3d, enables k8s auth, seeds secrets

# Then deploy the app — the Helm chart enables Vault Agent injection by default
task k3d-redeploy
```

### Useful commands

```powershell
# Check Vault status
task vault-status

# Read a secret directly
$env:VAULT_ADDR='http://127.0.0.1:8200'; $env:VAULT_TOKEN='root'
vault kv get secret/python-project/dev

# Update a secret
vault kv patch secret/python-project/dev EXAMPLE_VARIABLE_NAME="new-value"

# Open Vault UI
start http://localhost:8200/ui
```

---

## File layout

```
scripts/
  vault-dev-start.ps1     Start local Vault dev server, seed .dev.env secrets
  vault-render-env.ps1    Fetch secrets from Vault → .vault-secrets.env
  vault-k3d-setup.ps1     Install Vault in k3d, configure k8s auth, seed secrets

vault/
  vault-agent.hcl         Vault Agent config (alternative to the injector)

helm/
  vault/values.yaml       Vault Helm chart overrides (dev mode, local k3d)
  templates/
    deployment.yaml       App deployment with Vault Agent Injector annotations
    serviceaccount.yaml   ServiceAccount required for k8s auth
  values.yaml             App values — vault.enabled=true by default

src/
  main.py                 load_secrets() reads from Vault file or .dev.env
```

---

## How it works in Kubernetes

The Vault Helm chart installs:
- **Vault server** in dev mode (in-memory, auto-unsealed)
- **Vault Agent Injector** — a mutating webhook that intercepts pods annotated
  with `vault.hashicorp.com/agent-inject: "true"` and adds an init container
  plus a sidecar that write rendered secret files into `/vault/secrets/`.

The app's `deployment.yaml` carries these annotations:

```yaml
vault.hashicorp.com/agent-inject: "true"
vault.hashicorp.com/role: "python-project"
vault.hashicorp.com/agent-inject-secret-app.env: "secret/data/python-project/dev"
vault.hashicorp.com/agent-inject-template-app.env: |
  {{- with secret "secret/data/python-project/dev" -}}
  {{- range $k, $v := .Data.data -}}
  {{ $k }}={{ $v }}
  {{ end -}}
  {{- end -}}
vault.hashicorp.com/agent-pre-populate-only: "true"
```

`agent-pre-populate-only: true` means the init container writes the file before
the app starts and exits — no long-lived sidecar unless you want live rotation.
Remove that annotation to get continuous secret rotation.

---

## Disabling Vault (fallback mode)

Set `vault.enabled=false` in `helm/values.yaml` to go back to the original
k8s Secret / `secretGenerator` path — no other code changes needed.

---

## Security notes

- Vault dev mode is **in-memory only** — secrets are lost when the pod/process
  restarts. That's fine for local dev; use Vault's persistent storage for staging/prod.
- The root token `root` is hardcoded for local convenience only.
- `.vault-secrets.env` is gitignored and should never be committed.
- For staging/prod, replace dev mode with an HA Vault cluster and use proper
  auth methods (AppRole, IRSA, etc.) and an Integrated Storage backend.
