IMAGE        = "registry.localhost:5001/python-project:local"
RELEASE_NAME = "python-project"
HELM_CHART   = "./helm"
NAMESPACE    = "default"
SECRET_KEYS  = ["EXAMPLE_VARIABLE_NAME"]

def load_dev_env(path=".dev.env"):
    env = {}
    for line in str(read_file(path)).splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        env[k.strip()] = v.strip()
    return env

dev_env = load_dev_env()

docker_build(
    IMAGE,
    context=".",
    dockerfile="Dockerfile",
    live_update=[
        sync("./src", "/app/src"),
    ],
)

secret_set_args = {
    "secrets.{}".format(k): dev_env.get(k, "")
    for k in SECRET_KEYS
}

k8s_yaml(
    helm(
        HELM_CHART,
        name=RELEASE_NAME,
        namespace=NAMESPACE,
        set=["{}={}".format(k, v) for k, v in secret_set_args.items()],
    )
)

k8s_resource(
    RELEASE_NAME,
    port_forwards=["8003:8000"],
    labels=["app"],
)

IMAGE2        = "registry.localhost:5001/python-project-app2:local"
RELEASE_NAME2 = "python-project-app2"
HELM_CHART2   = "./helm2"

docker_build(
    IMAGE2,
    context=".",
    dockerfile="Dockerfile.app2",
    live_update=[
        sync("./src2", "/app/src2"),
    ],
)

secret_set_args2 = {
    "secrets.{}".format(k): dev_env.get(k, "")
    for k in SECRET_KEYS
}

k8s_yaml(
    helm(
        HELM_CHART2,
        name=RELEASE_NAME2,
        namespace=NAMESPACE,
        set=["{}={}".format(k, v) for k, v in secret_set_args2.items()],
    )
)

k8s_resource(
    RELEASE_NAME2,
    port_forwards=["8004:8000"],
    labels=["app"],
)
