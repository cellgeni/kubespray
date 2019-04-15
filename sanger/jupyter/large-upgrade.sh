#!/usr/bin/env bash
# upgrades jupyter large
kubectl config use-context eta
helm upgrade jptl jupyterhub/jupyterhub --namespace jptl --version 0.8.0 --values jupyter-large-config.yaml
# helm upgrade --install jptl jupyterhub/jupyterhub --namespace jptl --version 0.8.0 --values jupyter-large-config.yaml