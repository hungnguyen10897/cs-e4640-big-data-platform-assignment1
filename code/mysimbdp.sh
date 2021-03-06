#!/bin/bash


# Start a new cluster
minikube start \
-p mysimbdp \
--kubernetes-version=v1.20.7 \
--memory=10g \
--nodes=3 \
--cpus=4 \
--disk-size=10g

# Delete cluster
minikube delete -p mysimbdp

# Check and install appropriate storage class
kubectl get storageclasses
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Deploy K8ssandra with Helm
helm repo add k8ssandra https://helm.k8ssandra.io/stable

# To reach Cassandra from outside cluster
# helm repo add traefik https://helm.traefik.io/traefik

helm repo update
