# 1.  Prerequisites

setenforce 0

systemctl disable iptables-services firewalld

systemctl stop iptables-services firewalld

2. Prepare the Hosts

echo "
172.31.123.251 node1

172.31.16.93 node2

172.31.16.190 node3

172.31.115.69 node4

172.31.106.23 node5

172.31.21.116 workspace" >> /etc/hosts

3. ETCD HA
4. Master HA
5. Add new Minions
