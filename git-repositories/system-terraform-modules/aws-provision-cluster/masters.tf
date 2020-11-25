#########################
# Initialisation Script #
#########################

data "aws_subnet" "master_subnet" {
  id = var.master_subnet_id[0]
}

locals {
  master_ip = cidrhost(data.aws_subnet.master_subnet.cidr_block, 12)
}

data "template_file" "node_provision" {
  template = file("${path.module}/scripts/node-provision.sh")
}

data "template_file" "master_provision" {
  template = file("${path.module}/scripts/master-provision.sh")

  vars = {
    kubeadm_token = var.kubeadm_token
    dns_name      = aws_route53_record.master.fqdn
    ip_address    = local.master_ip
    cluster_name  = module.label.id
    aws_region    = var.aws_region
    environment   = var.environment
    asg_name      = "${module.label.id}-worker"
    asg_min_nodes = var.min_worker_count
    asg_max_nodes = var.max_worker_count
    public_hosted_zone_id = var.public_hosted_zone_id
    private_hosted_zone_id = var.private_hosted_zone_id
    aws_subnets   = join(" ", concat(var.worker_subnet_ids, var.master_subnet_id))
  }
}

data "template_file" "master_cloudinit" {
  template = file("${path.module}/scripts/master-cloudinit.yaml")

  vars = {
    calico_yaml = base64gzip(file("${path.module}/scripts/calico.yaml"))
    istio_yaml = base64gzip(file("${path.module}/scripts/istio.yaml"))
    provision_sh = base64gzip(data.template_file.master_provision.rendered)
  }
}

data "template_cloudinit_config" "master" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "cloud-init-config.yaml"
    content_type = "text/cloud-config"
    content      = data.template_file.master_cloudinit.rendered
  }

  part {
    filename     = "init-node.sh"
    content_type = "text/x-shellscript"
    content      = data.template_file.node_provision.rendered
  }
}

#################
# Node Policies #
#################

data "template_file" "master_policy_json" {
  template = file("${path.module}/templates/master-policy.json.tmpl")

  vars = {}
}

resource "aws_iam_policy" "master_policy" {
  name        = "${module.label.id}-master"
  path        = "/"
  description = "Policy for role ${module.label.id}-master"
  policy      = data.template_file.master_policy_json.rendered
}

resource "aws_iam_role" "master_role" {
  name = "${module.label.id}-master"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_policy_attachment" "master-attach" {
  name = "master-attachment"
  roles = [aws_iam_role.master_role.name]
  policy_arn = aws_iam_policy.master_policy.arn
}

resource "aws_iam_instance_profile" "master_profile" {
  name = "${module.label.id}-master"
  role = aws_iam_role.master_role.name
}

#########
# Nodes #
#########

resource "aws_instance" "master" {
  instance_type = var.master_instance_type

  ami = data.aws_ami.centos7.id

  key_name = module.key_pair.this_key_pair_key_name

  subnet_id = var.master_subnet_id[0]

  associate_public_ip_address = false

  private_ip = local.master_ip

  vpc_security_group_ids = [
    aws_security_group.kubernetes.id,
  ]

  iam_instance_profile = aws_iam_instance_profile.master_profile.name

  user_data = data.template_cloudinit_config.master.rendered

  tags = merge(
  module.label.tags,
  {
    "Name"                                               = join("-", [module.label.id, "master"])
    format("kubernetes.io/cluster/%v", module.label.id) = "owned"
  }
  )

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "50"
    delete_on_termination = true
  }

  lifecycle {
    ignore_changes = [
      ami,
      user_data,
      associate_public_ip_address,
    ]
  }
}
