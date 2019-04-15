#!/usr/bin/env bash
# upgrades newest jupyter installation
kubectl config use-context eta
helm upgrade jpt jupyterhub/jupyterhub --namespace jpt --version 0.8.0 --values jupyter-github-auth.yaml
