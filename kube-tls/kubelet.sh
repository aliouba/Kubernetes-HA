#!/bin/bash
#
# Invoke this command with ./create-tls-assets-for-worker [ workerID ] [ WorkerIP ]

# The worker ID should be an integer,
# and will place TLS assets in `/etc/kubenetes/ssl/worker${workerID}/`
workerID=$1

# The private IP of the worker node.
WorkerIP=$2

mkdir -p /etc/kubernetes/ssl/worker${workerID};

cp ca.pem /etc/kubernetes/ssl/worker${workerID};

cp ca-key.pem /etc/kubernetes/ssl/worker${workerID};

cp worker-openssl.cnf /etc/kubernetes/ssl/worker${workerID};

# Place the actual api server hostname in the open ssl config file.
sed -i -e "s/WorkerIP/${WorkerIP}/g" /etc/kubernetes/ssl/worker${workerID}/worker-openssl.cnf;

openssl genrsa -out /etc/kubernetes/ssl/worker${workerID}/worker-key.pem 2048

WorkerIP=${WorkerIP} openssl req -new \
  -key /etc/kubernetes/ssl/worker${workerID}/worker-key.pem \
	-out /etc/kubernetes/ssl/worker${workerID}/worker.csr \
	-subj "/CN=worker${workerID}" \
	-config /etc/kubernetes/ssl/worker${workerID}/worker-openssl.cnf;

WorkerIP=${WorkerIP} openssl x509 -req \
  -in /etc/kubernetes/ssl/worker${workerID}/worker.csr \
	-CA /etc/kubernetes/ssl/worker${workerID}/ca.pem \
	-CAkey /etc/kubernetes/ssl/worker${workerID}/ca-key.pem \
	-CAcreateserial \
	-out /etc/kubernetes/ssl/worker${workerID}/worker.pem \
	-days 365 \
	-extensions v3_req \
	-extfile /etc/kubernetes/ssl/worker${workerID}/worker-openssl.cnf;

sudo chmod 600 /etc/kubernetes/ssl/worker${workerID}/*-key.pem
sudo chown root:root /etc/kubernetes/ssl/worker${workerID}/*-key.pem
