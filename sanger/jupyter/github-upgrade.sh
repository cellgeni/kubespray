#!/usr/bin/env bash
# upgrades newest jupyter installation
kubectl config use-context large-cellgeni
ssh -i ~/.ssh/farm4-head1-id_rsa -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -l ubuntu -Nf -L 16700:10.0.3.15:6443 172.27.18.144
helmold upgrade jpt jupyterhub/jupyterhub --namespace jpt --version 0.7.0 --values jupyter-github-auth.yaml # helmold is a custom command for helm ver. 2.9.1
