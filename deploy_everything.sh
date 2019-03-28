#!/usr/bin/env bash


# MAKE SURE YOU ARE ON THE RIGHT K8S CLUSTER CONTEXT
# # create temp dir
# cd `mktemp -d`

# install helm

install_helm(){
    curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash
    kubectl --namespace kube-system create serviceaccount tiller
    kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
    helm init --service-account tiller --wait
    kubectl patch deployment tiller-deploy --namespace=kube-system --type=json --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]'
}
helm version
RESULT=$?
case $RESULT in
    0) echo Helm is already installed;
    127) install_helm(); # if there is no `helm` command on the machine // `helm init --client-only` is an option as well
    130) install_helm(); # if the command is interrupted since server doesn't report tiller's version
else
  echo Helm exited with code $RESULT && exit 1;
fi

# download main repositories
if [ ! -d "kubespray-internal" ] ; then
    git clone https://gitlab.internal.sanger.ac.uk/cellgeni/kubespray.git kubespray-internal
fi
if [ ! -d "kubespray" ] ; then
    git clone https://github.com/cellgeni/kubespray.git 
fi

# deploy contour
kubectl apply -f https://j.hept.io/contour-deployment-rbac
# activate ingresses
kubectl apply -f kubespray/sanger/ingress/contour-ws.yaml --save-config
kubectl apply -f kubespray/sanger/ingress/ingress-default-new-cluster.yaml --save-config


# deploy storage classes
kubectl apply -f kubespray/sanger/storage/glustesfs/glusterfs-sc.yaml --save-config
kubectl apply -f kubespray/sanger/storage/sc-rw-once.yaml --save-config


# create secrets
kubectl create -f kubespray-internal/sanger/sites/secrets.yaml --save-config


# deploy jupyters
pushd `dirname $0`
cd kubespray/internal
helm upgrade --install jpt jupyterhub/jupyterhub --namespace jpt --version 0.8.0 --values jupyter-github-auth.yaml
helm upgrade --install jptl jupyterhub/jupyterhub --namespace jptl --version 0.8.0 --values jupyter-large-config.yaml
helm upgrade --install jptt jupyterhub/jupyterhub --namespace jptt --version 0.8.0 --values jupyter-test.yaml
popd


# deploy partslab
if [ ! -d "FORECasT" ] ; then
    git clone  https://github.com/cellgeni/FORECasT
fi
pushd `dirname $0`
cd FORECasT/k8s
for filename in $(ls); do
    kubectl apply -f $filename;
done;
popd 


# deploy isee
if [ ! -d "isee-shiny" ] ; then
    git clone  https://github.com/cellgeni/isee-shiny
fi
pushd `dirname $0`
cd isee-shiny/k8s
for filename in $(ls); do
    kubectl apply -f $filename;
done;
popd 

# deploy scfind
for filename in $(ls kubespray/sites/scfind); do
    kubectl apply -f $filename --save-config;
done;


# deploy asthma
for filename in $(ls kubespray/sites/asthma); do
    kubectl apply -f $filename --save-config;
done;


# deploy spatial-transcriptomics
for filename in $(ls kubespray/sites/spatial_transcriptomics); do
    kubectl apply -f $filename --save-config;
done;


# deploy nextflow-web
# deploy nextflow
kubectl apply -f kubespray/sanger/storage/NF-pvc.yaml --save-config

# deploy prometheus & grafana
helm install --name grafana --namespace monitoring --values kubespray/sanger/services/monitoring/grafana.yaml stable/grafana
helm install --name prometheus --namespace monitoring -f kubespray/sanger/services/monitoring/prometheus.yaml stable/prometheus
