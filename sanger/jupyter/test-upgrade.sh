#!/usr/bin/env bash
# upgrades newest jupyter installation
kubectl config use-context eta
helm upgrade jptt jupyterhub/jupyterhub --namespace jptt --version 0.8.0 --values jupyter-test.yaml
# helm upgrade --install jptt jupyterhub/jupyterhub --namespace jptt --version 0.8.0 --values jupyter-test.yaml