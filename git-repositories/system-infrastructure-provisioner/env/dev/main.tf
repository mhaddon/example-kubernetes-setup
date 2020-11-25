module "kubeadm-token" {
  source = "git@github.com:scholzj/terraform-random-kubeadm-token.git?ref=master"
}

module "aws-vpc" {
  source = "git@github.com:mhaddon/example-kubernetes-setup.git//git-repositories/system-terraform-modules/aws-vpc?ref=master"

  vpc_cidr_block = "172.16.0.0/16"

  vpc_availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  vpc_private_subnets = ["172.16.100.0/24", "172.16.110.0/24", "172.16.120.0/24", "172.16.130.0/24"]
  vpc_public_subnets  = ["172.16.10.0/24", "172.16.20.0/24", "172.16.30.0/24"]

  namespace = "K8S"
  environment = "dev"
  service_name = "vpc"
  stage = "infra"
}

module "aws-private-hosted-zone" {
  source = "git@github.com:mhaddon/example-kubernetes-setup.git//git-repositories/system-terraform-modules/aws-private-hosted-zone?ref=master"

  domain = "aws.haddon.me"
  vpc_ids = [module.aws-vpc.vpc_id]

  namespace = "K8S"
  environment = "dev"
  service_name = "zone"
  stage = "infra"
}

module "aws-repositories-ecr" {
  source = "git@github.com:mhaddon/example-kubernetes-setup.git//git-repositories/system-terraform-modules/aws-ecr?ref=master"

  namespace = "K8S"
  environment = "dev"
  stage = "infra"

  repositories = [
    "my-app"
  ]
}

module "aws-ecr-triggers" {
  source = "git@github.com:mhaddon/example-kubernetes-setup.git//git-repositories/system-terraform-modules/aws-ecr-triggers?ref=master"

  namespace = "K8S"
  environment = "dev"
  stage = "infra"
  service_name = "ecr-trigger"

  repositories = module.aws-repositories-ecr.repository_names

  trigger_endpoint = "https://tekton.aws.haddon.me/docker/trigger"
}

data "http" "my-ip" {
  url = "http://ipv4.icanhazip.com"
}

module "aws-kubernetes-cluster" {
  source = "git@github.com:mhaddon/example-kubernetes-setup.git//git-repositories/system-terraform-modules/aws-provision-cluster?ref=master"

  namespace = "K8S"
  environment = "dev"
  stage = "infra"

  vpc_id = module.aws-vpc.vpc_id
  aws_region    = "eu-west-1"
  master_instance_type = "t3.xlarge"
  worker_instance_type = "t3.xlarge"
  ssh_access_cidr = ["${chomp(data.http.my-ip.body)}/32"]
  api_access_cidr = ["${chomp(data.http.my-ip.body)}/32"]
  min_worker_count = 3
  max_worker_count = 3
  public_hosted_zone_id = "Z003676927M0CUVI8I07B"
  private_hosted_zone_id = module.aws-private-hosted-zone.id
  private_hosted_zone_domain = module.aws-private-hosted-zone.domain
  kubeadm_token = trimspace(module.kubeadm-token.token)

  master_subnet_id = [ module.aws-vpc.vpc_private_subnets[0] ]
  worker_subnet_ids = slice(module.aws-vpc.vpc_private_subnets, 1, length(module.aws-vpc.vpc_private_subnets))
}

