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
sudo apt-get update

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

sudo docker run hello-world

### Kubernetes setup ###


sudo apt install apt-transport-https curl -y

# Add APT repository
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes components
apt update && apt install -y kubeadm=1.17.17-00 kubelet=1.17.17-00 kubectl=1.17.17-00 kubernetes-cni

# Change Docker Cgroup Driver
sudo mkdir /etc/docker
echo '{"exec-opts": ["native.cgroupdriver=systemd"]}' >> /etc/docker/daemon.json

sudo systemctl enable docker
sudo systemctl daemon-reload
sudo systemctl restart docker

# Do not allow automatic updates for kubeadm kubectl and kubelet
apt-mark hold kubeadm=1.17.17-00 kubelet=1.17.17-00 kubectl=1.17.17-00 kubernetes-cni

# Fix kubeadm init not working and initialize K8s masser node
rm /etc/containerd/config.toml
systemctl restart containerd
kubeadm init --pod-network-cidr=10.244.0.0/16

# Deploy a Pod Network
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# Use different than root user to run the cluster
mkdir -p /home/nvelev/.kube
sudo cp /etc/kubernetes/admin.conf /home/nvelev/.kube/config
sudo chown nvelev:nvelev /home/nvelev/.kube/config

# Add tab-complete for kubernetes
echo 'source <(kubectl completion bash)' >>~/.bashrc
