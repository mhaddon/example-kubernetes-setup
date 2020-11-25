resource "tls_private_key" "keypair" {
  algorithm = "RSA"
}

resource "local_file" "private-key" {
  content     = tls_private_key.keypair.private_key_pem
  filename = ".ssh/${module.label.id}"

  file_permission = "400"
}

resource "local_file" "public-key" {
  content     = tls_private_key.keypair.public_key_openssh
  filename = ".ssh/${module.label.id}.pub"

  file_permission = "400"
}

module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name   = module.label.id
  public_key = tls_private_key.keypair.public_key_openssh

  tags = module.label.tags
}