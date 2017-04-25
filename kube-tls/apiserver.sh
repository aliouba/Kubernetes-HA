#!/bin/bash
#
# Invoke this command with ./create-tls-assets-for-worker [ K8S_API_SERVER_HOSTNAME ]

# The hostname of the master node load balancer. You may want to change
# the `openssl-config/apiserver-openssl.cnf` depending on how you expect
# nodes and admins to reach the Kubernetes API server.
K8S_API_SERVER_HOSTNAME=$1


mkdir -p /etc/kubernetes/ssl/apiserver/;
cp apiserver-openssl.cnf /etc/kubernetes/ssl/apiserver/;

# Place the actual api server hostname in the open ssl config file.
sed -i -e "s/K8S_API_SERVER_HOSTNAME/${K8S_API_SERVER_HOSTNAME}/g" /etc/kubernetes/ssl/apiserver/apiserver-openssl.cnf;

openssl genrsa -out /etc/kubernetes/ssl/apiserver/apiserver-key.pem 2048;

openssl req -new \
	-key /etc/kubernetes/ssl/apiserver/apiserver-key.pem \
	-out /etc/kubernetes/ssl/apiserver/apiserver.csr \
	-subj "/CN=kube-apiserver" \
	-config /etc/kubernetes/ssl/apiserver/apiserver-openssl.cnf;

openssl x509 -req -in /etc/kubernetes/ssl/apiserver/apiserver.csr \
	-CA /etc/kubernetes/ssl/ca/ca.pem \
	-CAkey /etc/kubernetes/ssl/ca/ca-key.pem \
	-CAcreateserial \
	-out /etc/kubernetes/ssl/apiserver/apiserver.pem \
	-days 365 \
	-extensions v3_req \
	-extfile /etc/kubernetes/ssl/apiserver/apiserver-openssl.cnf;
