#!/bin/bash

#set -eu # European Union mode

LOG_DIR="/var/log/k8s"

mkdir -p "$LOG_DIR"

trap 'rm "/tmp/master.key" &> /dev/null' EXIT

exec &> "$LOG_DIR/script.log"

export ENVIRONMENT="${environment}"
export KUBEADM_TOKEN="${kubeadm_token}"
export DNS_NAME="${dns_name}"
export IP_ADDRESS="${ip_address}"
export CLUSTER_NAME="${cluster_name}"
export ASG_NAME="${asg_name}"
export ASG_MIN_NODES="${asg_min_nodes}"
export ASG_MAX_NODES="${asg_max_nodes}"
export AWS_REGION="${aws_region}"
export AWS_SUBNETS="${aws_subnets}"
export PUBLIC_HOSTED_ZONE_ID="${public_hosted_zone_id}"
export PRIVATE_HOSTED_ZONE_ID="${private_hosted_zone_id}"
export CLUSTER_NAME="${cluster_name}"
export KUBERNETES_VERSION="1.19.3"
DNS_NAME=$(echo "$DNS_NAME" | tr 'A-Z' 'a-z') #enforce lower-case dns
FULL_HOSTNAME="$(curl -s http://169.254.169.254/latest/meta-data/hostname)" # We need to match the hostname expected by kubeadm an the hostname used by kubelet

echo "Provisioning Master-Node"

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

##########################
# Install AWS-CLI-Client #
##########################
echo "│   ├ AWS CLI Client..."
(
  yum install -y epel-release
  yum install -y python2-pip
  pip install awscli --upgrade
) >> "$LOG_DIR/aws-cli.log"

###############
# Install Git #
###############
echo "│   ├ Git..."
(
  yum install -y git
) >> "$LOG_DIR/git.log"

###############
# Install JQ #
###############
echo "│   ├ JQ..."
(
  yum install -y jq
) >> "$LOG_DIR/jq.log"

####################
# Install Kubeseal #
####################
echo "│   ├ Kubeseal..."
(
  curl -L https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.13.1/kubeseal-linux-amd64 > kubeseal
  install -m 755 kubeseal /usr/bin/kubeseal
) >> "$LOG_DIR/kubeseal.log"

###############
# Install K9S #
###############
echo "│   ├ K9S..."
(
  curl -L https://github.com/derailed/k9s/releases/download/v0.24.1/k9s_Linux_x86_64.tar.gz > k9s.tar.gz
  tar xzf k9s.tar.gz
  mv k9s /usr/bin/k9s
) >> "$LOG_DIR/k9s.log"

#####################
# Install Kustomize #
#####################
echo "│   ├ Kustomize..."
(
  curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
  mv kustomize /usr/bin/kustomize
) >> "$LOG_DIR/kustomize.log"

#############################
# Install Argo Rollouts CLI #
#############################
echo "│   ├ Argo Rollouts CLI..."
(
  curl -LO "https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-darwin-amd64"
  chmod +x ./kubectl-argo-rollouts-darwin-amd64
  sudo mv ./kubectl-argo-rollouts-darwin-amd64 /usr/bin/kubectl-argo-rollouts
) >> "$LOG_DIR/argo-rollouts-cli.log"

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
echo "│   ├ Install..."
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

echo "│   ├ Initialize Master..."
(
  cat > /tmp/kubeadm.yaml <<EOF
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: $KUBEADM_TOKEN
  ttl: 0s
  usages:
  - signing
  - authentication
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  kubeletExtraArgs:
    cloud-provider: aws
    read-only-port: "10255"
  name: $FULL_HOSTNAME
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
apiServer:
  certSANs:
  - $DNS_NAME
  - $IP_ADDRESS
  extraArgs:
    cloud-provider: aws
    api-audiences: api,istio-ca
    service-account-issuer: kubernetes.default.svc
    service-account-key-file: /etc/kubernetes/pki/sa.key
    service-account-signing-key-file: /etc/kubernetes/pki/sa.key
  timeoutForControlPlane: 5m0s
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager:
  extraArgs:
    cloud-provider: aws
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: k8s.gcr.io
kubernetesVersion: v$KUBERNETES_VERSION
networking:
  podNetworkCidr: 192.168.0.0/16
  dnsDomain: cluster.local
  podSubnet: ""
  serviceSubnet: 10.96.0.0/12
scheduler: {}
---
EOF
  kubeadm reset --force
  kubeadm init --config /tmp/kubeadm.yaml
) >> "$LOG_DIR/kubernetes.log"

# Use the local kubectl config for further kubectl operations
export KUBECONFIG=/etc/kubernetes/admin.conf

##########
# Calico #
##########
echo "│   ├ Install Calico..."
(
  kubectl apply -f /tmp/calico.yaml
) >> "$LOG_DIR/calico.log"

###################
# Configure Admin #
###################
echo "│   ├ Configure Admin..."
(
  kubectl create clusterrolebinding admin-cluster-binding --clusterrole=cluster-admin --user=admin
) >> "$LOG_DIR/kubernetes.log"

#####################
# Create KubeConfig #
#####################
echo "│   ├ Create KubeConfig..."
(
  export KUBECONFIG_OUTPUT=/home/centos/kubeconfig_ip
  kubeadm alpha kubeconfig user \
    --client-name admin \
    --apiserver-advertise-address $IP_ADDRESS \
    > $KUBECONFIG_OUTPUT
  chown centos:centos $KUBECONFIG_OUTPUT
  chmod 0600 $KUBECONFIG_OUTPUT

  cp /home/centos/kubeconfig_ip /home/centos/kubeconfig
  sed -i "s/server: https:\/\/$IP_ADDRESS:6443/server: https:\/\/$DNS_NAME:6443/g" /home/centos/kubeconfig
  chown centos:centos /home/centos/kubeconfig
  chmod 0600 /home/centos/kubeconfig

  # todo change with a more restricted user - potentially read-only
  cp /home/centos/kubeconfig /var/kubeconfig
  chown ssm-user:ssm-user /var/kubeconfig
  chmod 0644 /var/kubeconfig

  echo 'export KUBECONFIG=/home/centos/kubeconfig' >> "/home/centos/.bashrc"
  echo 'export KUBECONFIG=/var/kubeconfig' >> "/etc/.bashrc"
  echo 'export KUBECONFIG=/var/kubeconfig' >> "/etc/profile"
) >> "$LOG_DIR/kubernetes.log"

###################
# Provision Istio #
###################
echo "├── Provisioning Istio..."
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.7.5 TARGET_ARCH=x86_64 sh - >> "$LOG_DIR/istio.log"
if [[ "$(istioctl verify-install 2>&1)" =~ "Istio is installed successfully" ]]; then
  echo "│   └ Istio is already installed - Please rebuild cluster to update to avoid integration issues."
else
  /istio-1.7.5/bin/istioctl install -f "/tmp/istio.yaml" -c "/etc/kubernetes/admin.conf" >> "$LOG_DIR/istio.log" 2>&1
fi

############################
# Provision Core Resources #
############################
echo "└── Provisioning Core Resources..."
(
  kubectl apply -k "https://github.com/mhaddon/example-kubernetes-setup//git-repositories/system-infrastructure-provisioner/base/namespaces"
  kubectl apply -k "https://github.com/mhaddon/example-kubernetes-setup//git-repositories/system-infrastructure-provisioner/base/priorities"
) >> "$LOG_DIR/provision.log"

####################
# Provision ArgoCD #
####################
echo "    ├ Provisioning ArgoCD..."
(
  kubectl apply -k "https://github.com/mhaddon/example-kubernetes-setup//git-repositories/system-infrastructure-argocd/env/$ENVIRONMENT"
) >> "$LOG_DIR/argocd.log"

########################################
# Provision Operator Lifecycle Manager #
########################################
echo "    ├ Provisioning OLM..."
(
  kubectl apply -k "https://github.com/mhaddon/example-kubernetes-setup//git-repositories/system-infrastructure-olm/env/$ENVIRONMENT"
) >> "$LOG_DIR/olm.log"

sleep 15

############################
# Provision Sealed-Secrets #
############################
echo "    ├ Provisioning Sealed-Secrets..."
(
  kubectl apply -k "https://github.com/mhaddon/example-kubernetes-setup//git-repositories/system-infrastructure-sealedsecrets/env/$ENVIRONMENT"
  sleep 90 # todo, replace this sleep with a wait until the sealedsecret crd is ready
  aws configure set region "eu-west-1"
  aws ssm get-parameter --name "/master.key" --with-decryption | jq ".Parameter.Value" -r > "/tmp/master.key"
  ( kubectl apply -f "/tmp/master.key" 2>&1 ) || true #todo remove '|| true', this is to stop crashes when re-applying the masterkey
  kubectl delete pod -n "kube-system" -l "app.kubernetes.io/name=sealed-secrets"
  rm "/tmp/master.key" &> /dev/null
  sleep 15
) >> "$LOG_DIR/sealed-secrets.log"

##########################
# Provision Cert-Manager #
##########################
echo "    ├ Provisioning Cert-Manager..."
(
  kubectl apply -k "https://github.com/mhaddon/example-kubernetes-setup//git-repositories/system-infrastructure-certmanager/env/$ENVIRONMENT"
) >> "$LOG_DIR/certmanager.log"

sleep 90

#################################
# Provision Cert-Manager-Config #
#################################
echo "    ├ Provisioning Cert-Manager-Config..."
(
  kustomize build "https://github.com/mhaddon/example-kubernetes-setup/git-repositories/system-infrastructure-certmanager-config/env/$ENVIRONMENT" \
    | envsubst '$${PUBLIC_HOSTED_ZONE_ID}' \
    | kubectl apply -f -
) >> "$LOG_DIR/certmanager.log"

################################
# Provision Cluster-Autoscaler #
################################
echo "    ├ Provisioning Cluster-Autoscaler..."
(
  kustomize build "https://github.com/mhaddon/example-kubernetes-setup/git-repositories/system-infrastructure-cluster-autoscaler/env/$ENVIRONMENT" \
    | envsubst '$${CLUSTER_NAME}' \
    | kubectl apply -f -
) >> "$LOG_DIR/cluster-autoscaler.log"

##########################
# Provision External-DNS #
##########################
echo "    ├ Provisioning External-DNS..."
(
  export DOMAIN_FILTER="aws.haddon.me"

  kustomize build "https://github.com/mhaddon/example-kubernetes-setup/git-repositories/system-infrastructure-external-dns/env/$ENVIRONMENT" \
    | envsubst '$${DOMAIN_FILTER} $${PUBLIC_HOSTED_ZONE_ID} $${PRIVATE_HOSTED_ZONE_ID}' \
    | kubectl apply -f -
) >> "$LOG_DIR/external-dns.log"

######################
# Provision Platform #
######################
echo "    └ Provisioning Platform..."
(
  kubectl apply -k "https://github.com/mhaddon/example-kubernetes-setup//git-repositories/system-infrastructure-platform/env/$ENVIRONMENT"
) >> "$LOG_DIR/platform.log"

