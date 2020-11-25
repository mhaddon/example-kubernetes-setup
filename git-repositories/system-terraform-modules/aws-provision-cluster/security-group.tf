resource "aws_security_group" "kubernetes" {
  vpc_id = var.vpc_id
  name   = module.label.id

  tags = merge(
  {
    "Name"                                               = module.label.id
    format("kubernetes.io/cluster/%v", module.label.id) = "owned"
  },
  module.label.tags,
  )
}

resource "aws_security_group_rule" "allow_all_outbound_from_kubernetes" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kubernetes.id
}

resource "aws_security_group_rule" "allow_ssh_from_cidr" {
  count     = length(var.ssh_access_cidr)
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks       = [var.ssh_access_cidr[count.index]]
  security_group_id = aws_security_group.kubernetes.id
}

resource "aws_security_group_rule" "allow_cluster_crosstalk" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes.id
  security_group_id        = aws_security_group.kubernetes.id
}

resource "aws_security_group_rule" "allow_api_from_cidr" {
  count     = length(var.api_access_cidr)
  type      = "ingress"
  from_port = 6443
  to_port   = 6443
  protocol  = "tcp"
  cidr_blocks       = [var.api_access_cidr[count.index]]
  security_group_id = aws_security_group.kubernetes.id
}