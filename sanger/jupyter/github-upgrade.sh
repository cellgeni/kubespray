#!/usr/bin/env bash
# upgrades newest jupyter installation
kubectl config use-context eta
ssh -i ~/.ssh/farm4-head1-id_rsa -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -l ubuntu -Nf -L 16900:10.0.3.15:6443 172.27.18.144
helm upgrade jpt jupyterhub/jupyterhub --namespace jpt --version 0.8.0 --values jupyter-github-auth.yaml
