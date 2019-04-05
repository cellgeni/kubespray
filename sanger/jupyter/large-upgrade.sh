#!/usr/bin/env bash
# upgrades jupyter large
kubectl config use-context eta
ssh -i ~/.ssh/farm4-head1-id_rsa -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -l ubuntu -Nf -L 16900:10.0.3.15:6443 172.27.18.144
helm upgrade jptl jupyterhub/jupyterhub --namespace jptl --version 0.8.0 --values jupyter-large-config.yaml
# helm upgrade --install jptl jupyterhub/jupyterhub --namespace jptl --version 0.8.0 --values jupyter-large-config.yaml