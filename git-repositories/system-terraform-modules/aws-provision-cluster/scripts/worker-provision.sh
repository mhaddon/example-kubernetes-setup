#!/bin/bash

#set -eu # European Union mode

LOG_DIR="/var/log/k8s"

mkdir -p "$LOG_DIR"

exec &> "$LOG_DIR/script.log"

export KUBEADM_TOKEN=${kubeadm_token}
export MASTER_IP=${master_private_ip}
export DNS_NAME=${dns_name}
export KUBERNETES_VERSION="1.19.3"
DNS_NAME=$(echo "$DNS_NAME" | tr 'A-Z' 'a-z') #enforce lower-case dns
FULL_HOSTNAME="$(curl -s http://169.254.169.254/latest/meta-data/hostname)" # We need to match the hostname expected by kubeadm an the hostname used by kubelet

echo "Provisioning Worker-Node"

echo "├── Installing Dependencies..."

################################
# Install AWS-Cloudwatch-Agent #
################################
echo "│   ├ AWS Cloudwatch Agent..."
(
  yum install -y "https://s3.eu-west-1.amazonaws.com/amazoncloudwatch-agent-eu-west-1/centos/amd64/latest/amazon-cloudwatch-agent.rpm"
  systemctl enable amazon-cloudwatch-agent
  systemctl start amazon-cloudwatch-agent
) >> "$LOG_DIR/aws-cloudwatch.log"

#########################
# Install AWS-SSM-Agent #
#########################
echo "│   ├ AWS SSM Agent..."
(
  yum install -y "https://s3.eu-west-1.amazonaws.com/amazon-ssm-eu-west-1/latest/linux_amd64/amazon-ssm-agent.rpm"
  systemctl enable amazon-ssm-agent
  systemctl start amazon-ssm-agent
) >> "$LOG_DIR/aws-ssm.log"

##################
# Install Docker #
##################
echo "│   └ Docker..."
(
  yum install -y yum-utils device-mapper-persistent-data lvm2 docker
  systemctl enable docker
  systemctl start docker

  sysctl net.bridge.bridge-nf-call-iptables=1
  sysctl net.bridge.bridge-nf-call-ip6tables=1
) >> "$LOG_DIR/docker.log"

###################
# Disable SELinux #
###################
# todo - This should NOT be here, SELinux should be left enabled.
echo "├── Disable SELinux..."
is_enforced="$(getenforce)"
if [[ $is_enforced != "Disabled" ]]; then
  setenforce 0 >> "$LOG_DIR/selinux.log"
  sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config >> "$LOG_DIR/selinux.log"
fi

###########################
# CentOS Force Newer CA's #
###########################
echo "├── Cert Fix..."
(
  if cat /etc/*release | grep ^NAME= | grep CentOS ; then
      rm -rf /etc/ssl/certs/ca-certificates.crt/
      cp /etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt
  fi
) >> "$LOG_DIR/cert_fix.log"

##############
# Kubernetes #
##############
echo "├── Kubernetes..."
echo "    ├ Install..."
(
  cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

  yum install -y kubelet-$KUBERNETES_VERSION kubeadm-$KUBERNETES_VERSION kubernetes-cni

  systemctl enable kubelet
  systemctl start kubelet
) >> "$LOG_DIR/kubernetes.log"

echo "    └ Join Cluster..."
(
  cat >/tmp/kubeadm.yaml <<EOF
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: $MASTER_IP:6443
    token: $KUBEADM_TOKEN
    unsafeSkipCAVerification: true
  timeout: 5m0s
  tlsBootstrapToken: $KUBEADM_TOKEN
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  kubeletExtraArgs:
    cloud-provider: aws
    read-only-port: "10255"
  name: $FULL_HOSTNAME
---
EOF
  kubeadm reset --force
  kubeadm join --config /tmp/kubeadm.yaml
) >> "$LOG_DIR/kubernetes-join.log"