# Prerequisites

To follow the coding examples in the workshop, please install the following software:

* [Docker](https://www.docker.com)
* [Node.JS](https://nodejs.org) v18 or higher
* [minikube](https://minikube.sigs.k8s.io/docs/start/)
* [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
* [helm](https://helm.sh/docs/intro/install/)


## 1. Set up a Local Kubernetes Cluster

1. Configure minikube to use 4 CPUs and 4 GB of RAM for the cluster node.
Minikube offers various methods fro creating a node, called [drivers](https://minikube.sigs.k8s.io/docs/drivers/).
The following snippet assumes that you are using Docker as the driver, but you may change to another one, if desired.

    ```sh
    minikube config set cpus 4
    minikube config set memory 4096
    minikube config set driver docker
    ```

2. Create a cluster:

    ```sh
    minikube start --kubernetes-version=v1.27.4
    ```

3. Verify that the cluster is running:

    ```sh
    kubectl get nodes
    ```


## 2. Install Prometheus

1. Add the [Prometheus helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) repository to your helm configuration:

    ```sh
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    ```

2. Install the kube-prometheus stack in the `monitoring` namespace.
This may take a few minutes.

    ```sh
    kubectl create namespace monitoring
    helm install prometheus prometheus-community/kube-prometheus-stack \
      --set namespaceOverride=monitoring --set grafana.namespaceOverride=monitoring \
      --set kube-state-metrics.namespaceOverride=monitoring \
      --set prometheus-node-exporter.namespaceOverride=monitoring
    ```

3. Wait for all Prometheus pods to be ready. You can check this with the following command:

    ```sh
    kubectl get pods -n monitoring
    ```

4. Check if the Prometheus UI is available by forwarding a local port to its service.

    ```sh
    # Forward local port 9090 to the Prometheus service
    kubectl port-forward -n monitoring services/prometheus-kube-prometheus-prometheus 9090:9090

    # Go to http://localhost:9090 in your browser.
    # If you see the Prometheus query UI, everything is fine.
    # Stop the port forwarding using Ctrl-C
    ```


## 3. Deploy the Test Workload

This workshop uses the Kubernetes [resource-consumer](https://github.com/kubernetes/kubernetes/tree/master/test/images/resource-consumer) as the target workload. To deploy it, run the following command in a terminal in this folder:

    ```sh
    kubectl apply -f ./resource-consumer.yaml
    ```


## 4. Stopping and Deleting the Cluster

To temporarily stop the minikube cluster, run the following:

    ```sh
    minikube stop
    ```

You can resume the cluster operation using:

    ```sh
    minikube start

    # Wait for all pods to be running again
    watch kubectl get pods -A
    ```

To delete the cluster, run:

    ```sh
    minikube stop
    minikube delete
    ```