#!/usr/bin/env bash
username=$1
ns=$2
cluster="eta"

kubectl config set-credentials $username --client-certificate=$HOME/.certs/$username.crt  --client-key=$HOME/.certs/$username.key
kubectl config set-context $username-context --cluster=$cluster --namespace=$ns --user=$username
