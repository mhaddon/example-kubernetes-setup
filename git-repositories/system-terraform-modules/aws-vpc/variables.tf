variable "vpc_cidr_block" {
  description = "VPC Cidr Block"
}

variable "namespace" {
  description = "Descriptive information for the resources labeling and naming."
}

variable "environment" {
  description = "What environment is this? (dev, prod, accept)"
}

variable "service_name" {
  description = "Descriptive information for the resources labeling and naming."
}

variable "stage" {
  description = "Descriptive information for the resources labeling and naming."
}

variable "vpc_availability_zones" {
  description = "AZ's that our subnets will be within."
  type        = list(string)
}

variable "vpc_public_subnets" {
  description = "List of public subnet CIDRs."
  type        = list(string)
}

variable "vpc_private_subnets" {
  description = "List of private subnets CIDRs."
  type        = list(string)
}