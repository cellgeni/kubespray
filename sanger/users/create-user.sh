#/usr/bin/env bash
# $1 - username

# run from k8s master node

username = $1
period = 500 # days
mkdir $1 && cd $1
CA_LOCATION=/etc/kubernetes/ssl
openssl genrsa -out $username.key 2048
sudo openssl req -new -key $username.key -out $username.csr -subj "/CN=$1/O=bitnami"
openssl x509 -req -in $username.csr -CA $CA_LOCATION/ca.pem -CAkey $CA_LOCATION/ca-key.pem -CAcreateserial -out $username.crt -days $period
