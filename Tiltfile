IMAGE        = "registry.localhost:5001/python-project:local"
RELEASE_NAME = "python-project"
HELM_CHART   = "./helm"
NAMESPACE    = "default"
SECRET_KEYS  = ["EXAMPLE_VARIABLE_NAME"]

MON_RELEASE    = "kube-prometheus-stack"
MON_NAMESPACE  = "monitoring"
MON_VALUES     = "./helm/monitoring/values.yaml"

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

k8s_yaml(
    helm(
        "prometheus-community/kube-prometheus-stack",
        name=MON_RELEASE,
        namespace=MON_NAMESPACE,
        values=[MON_VALUES],
    )
)

k8s_resource(
    RELEASE_NAME,
    port_forwards=["8003:8000"],
    labels=["app"],
)

k8s_resource(
    MON_RELEASE + "-grafana",
    port_forwards=["3000:3000"],
    labels=["monitoring"],
)

k8s_resource(
    MON_RELEASE + "-prometheus",
    port_forwards=["9090:9090"],
    labels=["monitoring"],
)
