# -*- mode: Python -*-

# ── Config ────────────────────────────────────────────────────────────────────
IMAGE        = "registry.localhost:5001/python-project:local"
RELEASE_NAME = "python-project"
HELM_CHART   = "./helm"
NAMESPACE    = "default"
SECRET_KEYS  = ["EXAMPLE_VARIABLE_NAME"]

# ── Read .dev.env for secrets ─────────────────────────────────────────────────
def load_dev_env(path=".dev.env"):
    env = {}
    for line in read_file(path).splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        env[k.strip()] = v.strip()
    return env

dev_env = load_dev_env()

# ── Image build ───────────────────────────────────────────────────────────────
docker_build(
    IMAGE,
    context=".",
    dockerfile="Dockerfile",
    live_update=[
        # Sync src changes without rebuilding the image
        sync("./src", "/app/src"),
    ],
)

# ── Helm values / secrets ─────────────────────────────────────────────────────
secret_set_args = {
    "secrets.{}".format(k): dev_env.get(k, "")
    for k in SECRET_KEYS
}

# ── Helm deploy ───────────────────────────────────────────────────────────────
k8s_yaml(
    helm(
        HELM_CHART,
        name=RELEASE_NAME,
        namespace=NAMESPACE,
        set=["{}={}".format(k, v) for k, v in secret_set_args.items()],
    )
)

# ── Port forward ──────────────────────────────────────────────────────────────
k8s_resource(
    RELEASE_NAME,
    port_forwards=["8001:8000"],
    labels=["app"],
)