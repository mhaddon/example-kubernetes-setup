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

variable "repositories" {
  description = "Which repositories should we create triggers for?"
  type        = list(string)
}

variable "trigger_endpoint" {
  description = "Which endpoint should we notify our triggers to."
}