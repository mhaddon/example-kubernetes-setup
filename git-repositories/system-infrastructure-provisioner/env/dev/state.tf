terraform {
  backend "s3" {
    bucket     = "tf-states-n38fjn2m2"
    key        = "infra-dev.tfstate"
    region     = "eu-west-1"
    encrypt    = true
  }
}