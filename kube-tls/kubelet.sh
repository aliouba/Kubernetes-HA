#!/bin/bash

# The private IP of the worker node.
WORKER_IP=$1

mkdir -p /etc/kubernetes/ssl/worker;

cp ca.pem /etc/kubernetes/ssl/worker;

cp ca-key.pem /etc/kubernetes/ssl/worker;

cp worker-openssl.cnf /etc/kubernetes/ssl/worker;

# Place the actual api server hostname in the open ssl config file.
sed -i -e "s/WORKER_IP/${WORKER_IP}/g" /etc/kubernetes/ssl/worker/worker-openssl.cnf;

openssl genrsa -out /etc/kubernetes/ssl/worker/worker-key.pem 2048

WORKER_IP=${WORKER_IP} openssl req -new \
  -key /etc/kubernetes/ssl/worker/worker-key.pem \
	-out /etc/kubernetes/ssl/worker/worker.csr \
	-subj "/CN=worker" \
	-config /etc/kubernetes/ssl/worker/worker-openssl.cnf;

WORKER_IP=${WORKER_IP} openssl x509 -req \
  -in /etc/kubernetes/ssl/worker/worker.csr \
	-CA /etc/kubernetes/ssl/worker/ca.pem \
	-CAkey /etc/kubernetes/ssl/worker/ca-key.pem \
	-CAcreateserial \
	-out /etc/kubernetes/ssl/worker/worker.pem \
	-days 365 \
	-extensions v3_req \
	-extfile /etc/kubernetes/ssl/worker/worker-openssl.cnf;

sudo chmod 600 /etc/kubernetes/ssl/worker/*-key.pem
sudo chown root:root /etc/kubernetes/ssl/worker/*-key.pem
