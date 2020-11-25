variable "namespace" {
  description = "Descriptive information for the resources labeling and naming."
}

variable "environment" {
  description = "What environment is this? (dev, prod, accept)"
}

variable "stage" {
  description = "Descriptive information for the resources labeling and naming."
}

variable "repositories" {
  description = "Which repositories should we create on ECR?"
  type        = list(string)
}