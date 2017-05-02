#!/bin/bash
#
# Invoke this command with ./create-tls-assets-for-worker [ WORKER_ID ] [ WORKER_IP ]

# The worker ID should be an integer,
# and will place TLS assets in `/etc/kubenetes/ssl/worker${WORKER_ID}/`
WORKER_ID=$1

# The private IP of the worker node.
WORKER_IP=$2

mkdir -p /etc/kubernetes/ssl/worker${WORKER_ID};

cp ca.pem /etc/kubernetes/ssl/worker${WORKER_ID};

cp ca-key.pem /etc/kubernetes/ssl/worker${WORKER_ID};

cp worker-openssl.cnf /etc/kubernetes/ssl/worker${WORKER_ID};

# Place the actual api server hostname in the open ssl config file.
sed -i -e "s/WORKER_IP/${WORKER_IP}/g" /etc/kubernetes/ssl/worker${WORKER_ID}/worker-openssl.cnf;

openssl genrsa -out /etc/kubernetes/ssl/worker${WORKER_ID}/worker-key.pem 2048

WORKER_IP=${WORKER_IP} openssl req -new \
  -key /etc/kubernetes/ssl/worker${WORKER_ID}/worker-key.pem \
	-out /etc/kubernetes/ssl/worker${WORKER_ID}/worker.csr \
	-subj "/CN=worker${WORKER_ID}" \
	-config /etc/kubernetes/ssl/worker${WORKER_ID}/worker-openssl.cnf;

WORKER_IP=${WORKER_IP} openssl x509 -req \
  -in /etc/kubernetes/ssl/worker${WORKER_ID}/worker.csr \
	-CA /etc/kubernetes/ssl/worker${WORKER_ID}/ca.pem \
	-CAkey /etc/kubernetes/ssl/worker${WORKER_ID}/ca-key.pem \
	-CAcreateserial \
	-out /etc/kubernetes/ssl/worker${WORKER_ID}/worker.pem \
	-days 365 \
	-extensions v3_req \
	-extfile /etc/kubernetes/ssl/worker${WORKER_ID}/worker-openssl.cnf;
