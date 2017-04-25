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
# 4. Master HA
# 5. Add new Minions
