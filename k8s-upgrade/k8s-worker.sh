#!/bin/bash

# Disable ufw
ufw disable

# Disable swap
swapoff -a; sed -i '/swap/d' /etc/fstab

# Update sysctl settings for Kubernetes Networking
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

# Install Docker Engine
sudo apt-get update -y

sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y

sudo apt-get install docker-ce=5:19.03.15~3-0~ubuntu-bionic docker-ce-cli containerd.io docker-compose-plugin -y

### Kubernetes setup ###

sudo apt install apt-transport-https curl -y

# Add APT repository
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes components
apt update && apt install -y kubeadm=1.17.17-00 kubelet=1.17.17-00 kubectl=1.17.17-00 kubernetes-cni
apt-mark hold kubeadm=1.17.17-00 kubelet=1.17.17-00 kubectl=1.17.17-00 kubernetes-cni

# Change Docker Cgroup Driver
sudo mkdir /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{ "exec-opts": ["native.cgroupdriver=systemd"],
"log-driver": "json-file",
"log-opts":
{ "max-size": "100m" },
"storage-driver": "overlay2"
}
EOF

sudo systemctl enable docker
sudo systemctl daemon-reload
sudo systemctl restart docker

# Fix joining the cluster does not work
rm /etc/containerd/config.toml
systemctl restart containerd
