#!/bin/bash
# set -x

echo "Configuring Minikube to use 4 CPUs and 4 GB of memory"
minikube config set cpus 4
minikube config set memory 4096

echo "Cleaning up minikube files in container to ensure a clean cluster setup"
minikube delete

echo "Starting minikube K8s v1.27.4"
minikube start --kubernetes-version=v1.27.4 2>&1

echo "Installing Polaris CLI"
npm install -g @polaris-sloc/cli

echo "Adding Prometheus repo to helm"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "Installing Prometheus using helm"
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack \
  --set namespaceOverride=monitoring --set grafana.namespaceOverride=monitoring \
  --set kube-state-metrics.namespaceOverride=monitoring \
  --set prometheus-node-exporter.namespaceOverride=monitoring

echo "Minikube cluster setup complete. Please run 'kubectl get pods -A' to see if it is working properly."
