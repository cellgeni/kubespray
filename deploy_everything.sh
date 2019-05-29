#!/usr/bin/env bash

# notes before starting 

# MAKE SURE YOU ARE ON THE RIGHT K8S CLUSTER CONTEXT
# MAKE SURE KUBECTL VERSION IS AT MOST ONE MINOR REALEASE DIFFERENT FROM THE CLUSTER VERSION
# MAKE SURE HELM VERSION (IF EXISTS LOCALLY) IS >=2.11 (FOR JUPYTERHUB RELEASE 0.8.0)


# possible problems

# LoadBalancer quota exceeded
# someone already installed stuff on k8s that might clash with this script's installation



# create temp dir
cd `mktemp -d`


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
    pushd kubespray
    git fetch && git checkout k8s-1.13
    popd
fi

# deploy storage classes
kubectl apply -f kubespray/sanger/storage/glusterfs/glusterfs-sc.yaml
kubectl apply -f kubespray/sanger/storage/sc-rw-once.yaml


# deploy jupyters
helm upgrade --install jpt jupyterhub/jupyterhub --namespace jpt --version 0.8.0 --values kubespray-internal/sanger/sites/jupyter-github-auth.yaml
helm upgrade --install jptl jupyterhub/jupyterhub --namespace jptl --version 0.8.0 --values kubespray-internal/sanger/sites/jupyter-large-config.yaml
helm upgrade --install jptt jupyterhub/jupyterhub --namespace jptt --version 0.8.0 --values kubespray-internal/sanger/sites/jupyter-test.yaml

apply_all(){
    directory=$1
    pushd $directory 
    for filename in $(ls); do
        kubectl apply -f $filename;
    done;
    popd 
}

# deploy partslab
if [ ! -d "FORECasT" ] ; then
    git clone  https://github.com/cellgeni/FORECasT
fi
apply_all FORECasT/k8s


# deploy isee
if [ ! -d "isee-shiny" ] ; then
    git clone  https://github.com/cellgeni/isee-shiny
fi
pushd isee-shiny/k8s
kubectl apply -f pvc.yaml;
kubectl apply -f deployment.yaml;
kubectl apply -f service.yaml;
popd 

# deploy scfind
apply_all kubespray/sanger/sites/scfind


# deploy asthma
apply_all kubespray/sanger/sites/asthma


# deploy spatial-transcriptomics
apply_all kubespray/sanger/sites/spatial_transcriptomics


# deploy metabase
apply_all kubespray/sanger/sites/metabase


# deploy nextflow-web
# deploy nextflow
kubectl apply -f kubespray/sanger/storage/NF-pvc.yaml


# deploy prometheus & grafana
helm install --name grafana --namespace monitoring --values kubespray/sanger/services/monitoring/grafana.yaml stable/grafana
helm install --name prometheus --namespace monitoring -f kubespray/sanger/services/monitoring/prometheus.yaml stable/prometheus


# deploy contour
kubectl apply -f https://j.hept.io/contour-deployment-rbac
# activate ingresses for all installed deployments
kubectl apply -f kubespray/sanger/ingress/contour-ws.yaml
kubectl apply -f kubespray/sanger/ingress/ingress-default-new-cluster.yaml


# create secrets - must be created after namespaces exist
kubectl create -f kubespray-internal/sanger/sites/secrets.yaml

# install Galaxy
helm repo add galaxy-helm-repo https://pcm32.github.io/galaxy-helm-charts && helm repo update
kubectl apply -f sanger/services/galaxy/pvc.yaml
helm upgrade --install galaxy -f sanger/services/galaxy/galaxy-config.yaml galaxy-helm-repo/galaxy-stable

# install Mongodb
helm install --name mongodb \
  --set mongodbRootPassword=cellgeni,mongodbUsername=cellgeni,mongodbPassword=cellgeni,mongodbDatabase=wge,service.type=NodePort \
    stable/mongodb
# helm upgrade my-release \
#   --set service.type=NodePort \
#     stable/mongodb