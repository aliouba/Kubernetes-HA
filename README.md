# 1. Prerequisites

# Deactivate SELINUX

	setenforce 0 
	sed -i -e "s/enforcing/disabled/g" /etc/selinux/config
	
# Deactivate Firewalld and iptables-services

	systemctl disable iptables-services firewalld
	systemctl stop iptables-services firewalld

# Ensure that traffic will not be routed incorrectly by bypassing iptables 

	cat <<EOF >  /etc/sysctl.d/k8s.conf
	net.bridge.bridge-nf-call-ip6tables = 1
	net.bridge.bridge-nf-call-iptables = 1
	EOF
	sysctl --system

# 2. Prepare the Hosts

# Components

||Components|
|----|-----------|
|lb |Haproxy|
|master1 |docker, ETCD, Flannel, kubelet, kube-proxy, kube-apiserver, kube-controller-manager, kube-scheduler|
|master2|docker, ETCD, Flannel, kubelet, kube-proxy, kube-apiserver, kube-controller-manager, kube-scheduler|
|master3|docker, ETCD, Flannel, kubelet, kube-proxy, kube-apiserver, kube-controller-manager, kube-scheduler|
|node1|docker, Flannel, kubelet, kube-proxy|
|node2|docker, Flannel, kubelet, kube-proxy|

# Put Ip/hostname of all cluster nodes in each node, e.g:

	echo "
	172.31.22.158 master1
	172.31.113.50 master2
	172.31.116.25 master3
	172.31.109.29 node1
	172.31.123.255 node2
	172.31.106.167 lb" >> /etc/hosts

# Docker Installation on all nodes

	yum install docker -y
	systemctl enable docker
	systemctl start docker
	systemctl status docker -l
# if you are behind a proxy

You have to save in a USB device

	docker save gcr.io/google_containers/hyperkube:v1.6.2  quay.io/coreos/etcd:v3.1.5 gcr.io/google_containers/pause-amd64:3.0 > save.tar

Then, copy images in your registry. Don't forget to configure your docker host to pull images in the right registry.

	docker load --input save.tar
	docker images
		REPOSITORY                             TAG                 IMAGE ID            CREATED             SIZE
		gcr.io/google_containers/hyperkube     v1.6.2              47c16ab7f7d0        13 days ago         583 MB
		quay.io/coreos/etcd                    v3.1.5              169a91823cad        5 weeks ago         33.65 MB
		gcr.io/google_containers/pause-amd64   3.0                 99e59f495ffa        12 months ago       746.9 kB

# 3. ETCD HA

We will install our ETCD cluster on the master (master1,master2 and master3).

# Define the following var environments on the masters:

	export ETCD_VERSION=v3.1.5
	export TOKEN=my-etcd-token
	export CLUSTER_STATE=new
	export NAME_1=etcd-node-1
	export NAME_2=etcd-node-2
	export NAME_3=etcd-node-3
	export HOST_1=master1
	export HOST_2=master2
	export HOST_3=master3
	export DATA_DIR=/var/lib/etcd
	export CLUSTER=${NAME_1}=http://${HOST_1}:2380,${NAME_2}=http://${HOST_2}:2380,${NAME_3}=http://${HOST_3}:2380

# RUN ETCD on Master1

	export THIS_NAME=${NAME_1}
	export THIS_IP=${HOST_1}
	docker run --net=host \
	    --volume=${DATA_DIR}:/etcd-data \
	    --name etcd quay.io/coreos/etcd:${ETCD_VERSION} \
		/usr/local/bin/etcd \
		--data-dir=/etcd-data --name ${THIS_NAME} \
	    --name ${THIS_NAME} \
		--initial-advertise-peer-urls http://${THIS_IP}:2380 --listen-peer-urls http://${THIS_IP}:2380 \
		--advertise-client-urls http://${THIS_IP}:2379 --listen-client-urls http://${THIS_IP}:2379,http://127.0.0.1:2379 \
		--initial-cluster ${CLUSTER} \
		--initial-cluster-state ${CLUSTER_STATE} --initial-cluster-token ${TOKEN}

# RUN ETCD on Master2

	export THIS_NAME=${NAME_2}
	export THIS_IP=${HOST_2}
	docker run --net=host \
	    --volume=${DATA_DIR}:/etcd-data \
	    --name etcd quay.io/coreos/etcd:${ETCD_VERSION} \
		/usr/local/bin/etcd \
		--data-dir=/etcd-data --name ${THIS_NAME} \
	    --name ${THIS_NAME} \
		--initial-advertise-peer-urls http://${THIS_IP}:2380 --listen-peer-urls http://${THIS_IP}:2380 \
		--advertise-client-urls http://${THIS_IP}:2379 --listen-client-urls http://${THIS_IP}:2379,http://127.0.0.1:2379 \
		--initial-cluster ${CLUSTER} \
		--initial-cluster-state ${CLUSTER_STATE} --initial-cluster-token ${TOKEN}

# RUN ETCD on Master3

	export THIS_NAME=${NAME_3}
	export THIS_IP=${HOST_3}
	docker run --net=host \
	    --volume=${DATA_DIR}:/etcd-data \
	    --name etcd quay.io/coreos/etcd:${ETCD_VERSION} \
		/usr/local/bin/etcd \
		--data-dir=/etcd-data --name ${THIS_NAME} \
	    --name ${THIS_NAME} \
		--initial-advertise-peer-urls http://${THIS_IP}:2380 --listen-peer-urls http://${THIS_IP}:2380 \
		--advertise-client-urls http://${THIS_IP}:2379 --listen-client-urls http://${THIS_IP}:2379,http://127.0.0.1:2379 \
		--initial-cluster ${CLUSTER} \
		--initial-cluster-state ${CLUSTER_STATE} --initial-cluster-token ${TOKEN}

# Test ETCD installation 

curl http://master1:2379/v2/members

	{"members":[
	{"id":"ea8af9652ff027","name":"etcd-node-1","peerURLs":["http://master1:2380"],"clientURLs":["http://master1:2379"]},
	{"id":"7b6c720f0c92a3cf","name":"etcd-node-2","peerURLs":["http://master2:2380"],"clientURLs":["http://master2:2379"]},	
	{"id":"c17975036fa896c0","name":"etcd-node-3","peerURLs":["http://master3:2380"],"clientURLs":["http://master3:2379"]}
	]}

# 4. Start ETCD at startup (Master nodes)

# Create the systemd config file

	echo "
	[Unit]
	Description=Docker Container ETCD
	Requires=docker.service
	After=docker.service
	[Service]
	Restart=always
	ExecStart=/usr/bin/docker start etcd
	ExecStop=/usr/bin/docker stop -t etcd
	[Install]
	WantedBy=default.target
	" > /etc/systemd/system/container-etcd.service

# Enable Services

	systemctl daemon-reload
	systemctl enable container-etcd

# 5. Flannel 

# Installation (All nodes) 

	yum install flannel -y
	systemctl enable flanneld

# Determine Flannel Parameters

* Network Cidr, e.g: 92.168.0.0/16
* Network Name: e.g kube1
* Subnet length (segements), e.g /24
* Backend Type: vxlan or udp

# Save Flannel parametes in ETCD

	etcdctl mkdir /kube1/network
	etcdctl mk /kube1/network/config "{ \"Network\": \"192.168.0.0/16\", \"SubnetLen\": 24, \"Backend\": { \"Type\": \"vxlan\" } }"

# Configuration (All nodes)

	 vi /etc/sysconfig/flanneld
	FLANNEL_ETCD_ENDPOINTS="http://master1:2379,http://master2:2379,http://master3:2379"
	FLANNEL_ETCD_PREFIX="/kube1/network"

# Start Flannel (All nodes) et restart Docker

	systemctl start flanneld
	systemctl status flanneld -l
	systemctl restart docker

# Test Flannel 

	curl -L http://master1:2379/v2/keys/kube1/network/subnets | python -mjson.tool
		{
		    "action": "get",
		    "node": {
			"createdIndex": 14,
			"dir": true,
			"key": "/kube1/network/subnets",
			"modifiedIndex": 14,
			"nodes": [
			    {
				"createdIndex": 14,
				"expiration": "2017-05-10T18:53:20.544002297Z",
				"key": "/kube1/network/subnets/192.168.80.0-24",
				"modifiedIndex": 14,
				"ttl": 86300,
				"value": "{\"PublicIP\":\"172.31.22.158\",\"BackendType\":\"vxlan\",\"BackendData\":{\"VtepMAC\":\"62:b5:49:7d:31:db\"}}"
			    },
			    {
				"createdIndex": 16,
				"expiration": "2017-05-10T18:53:47.380825901Z",
				"key": "/kube1/network/subnets/192.168.88.0-24",
				"modifiedIndex": 16,
				"ttl": 86327,
				"value": "{\"PublicIP\":\"172.31.113.50\",\"BackendType\":\"vxlan\",\"BackendData\":{\"VtepMAC\":\"d2:73:5c:4b:47:b7\"}}"
			    },
			    {
				"createdIndex": 17,
				"expiration": "2017-05-10T18:53:49.47097372Z",
				"key": "/kube1/network/subnets/192.168.54.0-24",
				"modifiedIndex": 17,
				"ttl": 86329,
				"value": "{\"PublicIP\":\"172.31.116.25\",\"BackendType\":\"vxlan\",\"BackendData\":{\"VtepMAC\":\"f6:cf:70:8b:0c:09\"}}"
			    },
			    {
				"createdIndex": 18,
				"expiration": "2017-05-10T18:53:58.937946948Z",
				"key": "/kube1/network/subnets/192.168.8.0-24",
				"modifiedIndex": 18,
				"ttl": 86339,
				"value": "{\"PublicIP\":\"172.31.109.29\",\"BackendType\":\"vxlan\",\"BackendData\":{\"VtepMAC\":\"36:b0:31:fd:40:56\"}}"
			    },
			    {
				"createdIndex": 20,
				"expiration": "2017-05-10T18:54:02.559740492Z",
				"key": "/kube1/network/subnets/192.168.99.0-24",
				"modifiedIndex": 20,
				"ttl": 86342,
				"value": "{\"PublicIP\":\"172.31.123.255\",\"BackendType\":\"vxlan\",\"BackendData\":{\"VtepMAC\":\"d6:2b:a0:00:c3:09\"}}"
			    }
			]
		    }
		}


# 6. Master HA

	git clone https://github.com/aliouba/Kubernetes-HA
	export MASTERID=masterID # Master Id, e.g master1
	export THIS_IP=IP #Master Ip address, e.g 172.31.22.158

# TLS Assets (on master 1)

	cd Kubernetes-HA/kube-tls/

	./apiserver.sh 172.31.22.158 172.31.113.50 172.31.116.25 172.31.106.167
	chmod 600 /etc/kubernetes/ssl/apiserver/apiserver*-key.pem
	chown root:root /etc/kubernetes/ssl/apiserver/apiserver*-key.pem
	chmod 600 /etc/kubernetes/ssl/ca-key.pem
	chown root:root /etc/kubernetes/ssl/ca-key.pem
# Copy TLS assets on mster2 and add the following permissions	

	scp -r /etc/kubernetes/* root@master2:/etc/kubernetes/
	chmod 600 /etc/kubernetes/ssl/apiserver/apiserver*-key.pem
	chown root:root /etc/kubernetes/ssl/apiserver/apiserver*-key.pem
	chmod 600 /etc/kubernetes/ssl/ca-key.pem
	chown root:root /etc/kubernetes/ssl/ca-key.pem

# Copy TLS assets on mster3 and add the following permissions	

	scp -r /etc/kubernetes/* root@master3:/etc/kubernetes/
	chmod 600 /etc/kubernetes/ssl/apiserver/apiserver*-key.pem
	chown root:root /etc/kubernetes/ssl/apiserver/apiserver*-key.pem
	chmod 600 /etc/kubernetes/ssl/ca-key.pem
	chown root:root /etc/kubernetes/ssl/ca-key.pem

# Apiserver, scheduler, controller and proxy manifests

	mkdir -p /etc/kubernetes/manifests/
	cp -r ../kube-master/*.yaml /etc/kubernetes/manifests/
	cp -r ../kube-master/*.csv /etc/kubernetes/

# Kubelet Installation

	cp -r ../kube-master/*.service /lib/systemd/system/
	sed -i -e "s/THIS_IP/${THIS_IP}/g" /lib/systemd/system/kube-kubelet.service;

	wget https://dl.k8s.io/v1.6.4/kubernetes-server-linux-amd64.tar.gz -P /opt/
	cd /opt
	tar -xvf kubernetes-server-linux-amd64.tar.gz
	rm kubernetes-server-linux-amd64.tar.gz
	mv /opt/kubernetes/server/bin/kubectl /opt/kubernetes/server/bin/kubelet /usr/local/bin/
	rm -rf /opt/kubernetes
	sudo systemctl daemon-reload
	sudo systemctl start kube-kubelet
	sudo systemctl enable kube-kubelet
	sudo systemctl status kube-kubelet -l

# 7. Add new Minions

	export workerID=1
	export workerIP=172.31.109.29
	export lb=172.31.106.167

# TLS Assets

	git clone https://github.com/aliouba/Kubernetes-HA
	cd Kubernetes-HA/kube-tls/
	chmod +x kubelet.sh
	./kubelet.sh $workerID $workerIP

# Copy Sytemd files

	cp -r ../kube-worker/*.service /lib/systemd/system/
	sed -i -e "s/workerID/${workerID}/g" /lib/systemd/system/kube-kubelet.service;
	sed -i -e "s/workerIP/${workerIP}/g" /lib/systemd/system/kube-kubelet.service;
	sed -i -e "s/lb/${lb}/g" /lib/systemd/system/kube-proxy.service;
	sed -i -e "s/workerID/${workerID}/g" /lib/systemd/system/kube-proxy.service;

	mkdir -p /etc/kubernetes/worker${workerID}
	cp -r ../kube-worker/kubeconfig.yaml /etc/kubernetes/worker${workerID}/
	sed -i -e "s/workerID/${workerID}/g" /etc/kubernetes/worker${workerID}/kubeconfig.yaml;
	sed -i -e "s/lb/${lb}/g" /etc/kubernetes/worker${workerID}/kubeconfig.yaml;

# Kubelet and Kube-proxy Installation

	wget https://dl.k8s.io/v1.6.4/kubernetes-server-linux-amd64.tar.gz -P /opt/
	cd /opt
	tar -xvf kubernetes-server-linux-amd64.tar.gz
	rm kubernetes-server-linux-amd64.tar.gz
	cp /opt/kubernetes/server/bin/kube-proxy /opt/kubernetes/server/bin/kubelet /usr/local/bin/
	rm -rf /opt/kubernetes
	sudo systemctl daemon-reload
	sudo systemctl start kube-kubelet
	sudo systemctl enable kube-kubelet
	sudo systemctl status kube-kubelet -l


	sudo systemctl start kube-proxy
	sudo systemctl enable kube-proxy
	sudo systemctl status kube-proxy -l
