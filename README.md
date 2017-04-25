# 1. Prerequisites

# Deactivate SELINUS

setenforce 0 (Put SELINUX to disabled in /etc/selinux/config then restart the VM)

# Deactivate Firewalld and iptables-services

systemctl disable iptables-services firewalld

systemctl stop iptables-services firewalld

# 2. Prepare the Hosts

# Put Ip/hostname of all cluster nodes in /etc/hosts in each host, e.g:

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

export HOST_3=master2

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

# RUN ETCD on Master3

# 4. Master HA
# 5. Add new Minions
