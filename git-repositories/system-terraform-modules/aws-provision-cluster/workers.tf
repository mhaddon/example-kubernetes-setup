#########################
# Initialisation Script #
#########################
data "template_file" "worker_provision" {
  template = file("${path.module}/scripts/worker-provision.sh")

  vars = {
    kubeadm_token     = var.kubeadm_token
    master_ip         = local.master_ip
    master_private_ip = aws_instance.master.private_ip
    dns_name          = aws_route53_record.master.fqdn
  }
}

data "template_file" "worker_cloudinit" {
  template = file("${path.module}/scripts/worker-cloudinit.yaml")

  vars = {
    provision_sh = base64gzip(data.template_file.worker_provision.rendered)
  }
}


data "template_cloudinit_config" "worker" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "cloud-init-config.yaml"
    content_type = "text/cloud-config"
    content      = data.template_file.worker_cloudinit.rendered
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

data "template_file" "worker_policy_json" {
  template = file("${path.module}/templates/worker-policy.json.tmpl")

  vars = {}
}

resource "aws_iam_policy" "worker_policy" {
  name = "${module.label.id}-worker"
  path = "/"
  description = "Policy for role ${module.label.id}-worker"
  policy = data.template_file.worker_policy_json.rendered
}

resource "aws_iam_role" "worker_role" {
  name = "${module.label.id}-worker"

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

resource "aws_iam_policy_attachment" "worker-attach" {
  name       = "${module.label.id}-worker-attachment"
  roles      = [aws_iam_role.worker_role.name]
  policy_arn = aws_iam_policy.worker_policy.arn
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "${module.label.id}-worker"
  role = aws_iam_role.worker_role.name
}

#########
# Nodes #
#########

resource "aws_launch_configuration" "worker" {
  name_prefix          = "${module.label.id}-worker-"
  image_id             = data.aws_ami.centos7.id
  instance_type        = var.worker_instance_type
  key_name             = module.key_pair.this_key_pair_key_name
  iam_instance_profile = aws_iam_instance_profile.worker_profile.name

  security_groups = [
    aws_security_group.kubernetes.id,
  ]

  associate_public_ip_address = false

  user_data = data.template_cloudinit_config.worker.rendered

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "50"
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [user_data]
  }
}

resource "aws_autoscaling_group" "worker" {
  vpc_zone_identifier = var.worker_subnet_ids

  name                 = "${module.label.id}-worker"
  max_size             = var.max_worker_count
  min_size             = var.min_worker_count
  desired_capacity     = var.min_worker_count
  launch_configuration = aws_launch_configuration.worker.name

  tag {
    key                 = "kubernetes.io/cluster/${module.label.id}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${module.label.id}-worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}