IMAGE  = "registry.localhost:5001/python-project:local"
IMAGE2 = "registry.localhost:5001/python-project-app2:local"

OVERLAY  = "k8s/kustomize/overlays/dev"
OVERLAY2 = "k8s/kustomize/overlays/app2-dev"

local("powershell -ExecutionPolicy Bypass -File scripts/render-secrets.ps1 -Overlay dev")
local("powershell -ExecutionPolicy Bypass -File scripts/render-secrets.ps1 -Overlay app2-dev")

docker_build(
    IMAGE,
    context=".",
    dockerfile="Dockerfile",
    live_update=[
        sync("./src", "/app/src"),
    ],
)

docker_build(
    IMAGE2,
    context=".",
    dockerfile="Dockerfile.app2",
    live_update=[
        sync("./src2", "/app/src2"),
    ],
)

k8s_yaml(kustomize(OVERLAY))
k8s_yaml(kustomize(OVERLAY2))

k8s_resource(
    "dev-python-project",
    port_forwards=["8003:8000"],
    labels=["app"],
)

k8s_resource(
    "app2-dev-python-project-app2",
    port_forwards=["8004:8000"],
    labels=["app2"],
)
