variable "aws_region" {
  description = "AWS Region"
  default     = "eu-west-1"
}

variable "master_instance_type" {
  description = "Type of instance for master"
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "Type of instance for workers"
  default     = "t3.medium"
}

variable "master_subnet_id" {
  description = "The subnet-id to be used for the master instance. Master can be only in single subnet. All subnets have to belong to the same VPC."
  type        = list(string)
}

variable "worker_subnet_ids" {
  description = "The subnet-ids to be used for the worker instances. Workers can be in multiple subnets. Worker subnets can contain also the master subnet. If you want to run workers in different subnet(s) than master you have to tag the subnets with kubernetes.io/cluster/{cluster_name}=shared.  All subnets have to belong to the same VPC."
  type        = list(string)
}

variable "min_worker_count" {
  description = "Minimal number of worker nodes"
}

variable "max_worker_count" {
  description = "Maximal number of worker nodes"
}

variable "public_hosted_zone_id" {
  description = "The public hosted zone id for Route 53. Must match the zone domain for private_hosted_zone_domain."
}

variable "private_hosted_zone_id" {
  description = "The private hosted zone id for Route 53. Must match the zone domain for private_hosted_zone_domain."
}

variable "private_hosted_zone_domain" {
  description = "The domain (such as www.google.com), that our hosted_zone is for."
}

variable "ssh_access_cidr" {
  description = "List of CIDRs from which SSH access is allowed"
  type        = list(string)
  default = [
    "0.0.0.0/0",
  ]
}

variable "api_access_cidr" {
  description = "List of CIDRs from which API access is allowed"
  type        = list(string)
  default = [
    "0.0.0.0/0",
  ]
}

variable "namespace" {
  description = "Descriptive information for the resources labeling and naming."
}

variable "environment" {
  description = "What environment is this? (dev, prod, accept)"
}

variable "stage" {
  description = "Descriptive information for the resources labeling and naming."
}

variable "kubeadm_token" {
  description = "Generated Kubeadm token"
}

variable "vpc_id" {
  default = "VPC ID"
}