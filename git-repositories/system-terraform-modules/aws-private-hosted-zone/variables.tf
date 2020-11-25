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

variable "vpc_ids" {
  description = "What VPCs can use this domain zone?"
  type        = list(string)
}

variable "domain" {
  description = "Which domain does this zone belong to?"
}