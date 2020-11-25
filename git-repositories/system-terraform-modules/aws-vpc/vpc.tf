module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = module.label.id
  cidr = var.vpc_cidr_block

  azs             = var.vpc_availability_zones
  public_subnets  = var.vpc_public_subnets
  private_subnets = var.vpc_private_subnets

  enable_nat_gateway  = true
  single_nat_gateway  = false
  one_nat_gateway_per_az = false #todo true

  # allows private DNS to work, like service discovery
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_suffix = "public"
  private_subnet_suffix = "private"

  public_subnet_tags = {
    "kubernetes.io/role/elb": 1
    "kubernetes.io/cluster/k8s-dev": "owned"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb": 1
    "kubernetes.io/cluster/k8s-dev": "shared"
  }

  tags = {
    "Environment": module.label.environment
    "Namespace": module.label.namespace
    "Stage": module.label.stage
  }
}
