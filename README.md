# 1. Prerequisites

# Deactivate SELINUS

setenforce 0 (Put SELINUX to disabled in /etc/selinux/config then restart the VM)

# Deactivate Firewalld and iptables-services

systemctl disable iptables-services firewalld

systemctl stop iptables-services firewalld

# 2. Prepare the Hosts

# Put Ip/hostname of all cluster nodes (/etc/hosts) in each host:

echo "

172.31.23.4 master1

172.31.112.238 master2

172.31.16.190 master3

172.31.115.69 node1

172.31.106.23 node2

172.31.21.116 node3" >> /etc/hosts

# Docker Installation on all nodes

yum install docker -y

systemctl enable docker

systemctl start docker

systemctl status docker -l

# 3. ETCD HA

We will install our ETCD cluster on the master (master1,master2 and master3).

# Define the following var environments on each master:

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

# Save Flannel parametes in our ETCD

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
        "createdIndex": 19,
        "dir": true,
        "key": "/kube1/network/subnets",
        "modifiedIndex": 19,
        "nodes": [
            {
                "createdIndex": 23,
                "expiration": "2017-04-26T12:24:13.459780122Z",
                "key": "/kube1/network/subnets/192.168.74.0-24",
                "modifiedIndex": 23,
                "ttl": 86295,
                "value": "{\"PublicIP\":\"172.31.115.69\",\"BackendType\":\"vxlan\",\"BackendData\":{\"VtepMAC\":\"ea:13:52:35:7a:ac\"}}"
            },
            {
                "createdIndex": 25,
                "expiration": "2017-04-26T12:24:16.013425132Z",
                "key": "/kube1/network/subnets/192.168.76.0-24",
                "modifiedIndex": 25,
                "ttl": 86298,
                "value": "{\"PublicIP\":\"172.31.106.23\",\"BackendType\":\"vxlan\",\"BackendData\":{\"VtepMAC\":\"0e:8d:92:fe:a3:ac\"}}"
            },
            {
                "createdIndex": 26,
                "expiration": "2017-04-26T12:24:18.133121342Z",
                "key": "/kube1/network/subnets/192.168.89.0-24",
                "modifiedIndex": 26,
                "ttl": 86300,
                "value": "{\"PublicIP\":\"172.31.21.116\",\"BackendType\":\"vxlan\",\"BackendData\":{\"VtepMAC\":\"f2:f3:0c:6e:a3:62\"}}"
            },
            {
                "createdIndex": 19,
                "expiration": "2017-04-26T12:17:35.129928801Z",
                "key": "/kube1/network/subnets/192.168.87.0-24",
                "modifiedIndex": 19,
                "ttl": 85897,
                "value": "{\"PublicIP\":\"172.31.23.4\",\"BackendType\":\"vxlan\",\"BackendData\":{\"VtepMAC\":\"72:37:cd:18:58:60\"}}"
            },
            {
                "createdIndex": 21,
                "expiration": "2017-04-26T12:24:06.285121518Z",
                "key": "/kube1/network/subnets/192.168.13.0-24",
                "modifiedIndex": 21,
                "ttl": 86288,
                "value": "{\"PublicIP\":\"172.31.112.238\",\"BackendType\":\"vxlan\",\"BackendData\":{\"VtepMAC\":\"32:db:4f:2b:65:10\"}}"
            },
            {
                "createdIndex": 22,
                "expiration": "2017-04-26T12:24:10.814833173Z",
                "key": "/kube1/network/subnets/192.168.75.0-24",
                "modifiedIndex": 22,
                "ttl": 86293,
                "value": "{\"PublicIP\":\"172.31.16.190\",\"BackendType\":\"vxlan\",\"BackendData\":{\"VtepMAC\":\"d6:0c:dc:97:b6:65\"}}"
            }
        ]
    }
}



# 6. Master HA

export MASTERID=masterID

export THIS_IP=IP

# TLS Assets (on each master)

git clone https://github.com/aliouba/Kubernetes-HA

cd Kubernetes-HA/kube-tls/

./apiserver.sh $THIS_IP

chmod 600 /etc/kubernetes/ssl/apiserver/apiserver*-key.pem

chown root:root /etc/kubernetes/ssl/apiserver/apiserver*-key.pem

chmod 600 /etc/kubernetes/ssl/ca-key.pem

chown root:root /etc/kubernetes/ssl/ca-key.pem

# Apiserver, scheduler and controller Installation

mkdir -p /etc/kubernetes/manifests/

cp -r ../kube-master/*.yaml /etc/kubernetes/manifests/

cp -r ../kube-master/*.service /lib/systemd/system/

sed -i -e "s/THIS_IP/${THIS_IP}/g" /lib/systemd/system/kube-kubelet.service;

sed -i -e "s/MASTERID/${MASTERID}/g" /lib/systemd/system/kube-kubelet.service;


sudo systemctl daemon-reload

sudo systemctl start kube-kubelet

sudo systemctl enable kube-kubelet

sudo systemctl status kube-kubelet -l

# Kubelet Installation

wget https://dl.k8s.io/v1.6.2/kubernetes-server-linux-amd64.tar.gz -P /opt/

cd /opt

tar -xvf kubernetes-server-linux-amd64.tar.gz

rm kubernetes-server-linux-amd64.tar.gz


# 7. Add new Minions
