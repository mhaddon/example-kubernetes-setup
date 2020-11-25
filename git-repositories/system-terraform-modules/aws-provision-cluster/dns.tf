resource "aws_route53_record" "master" {
  zone_id = var.private_hosted_zone_id
  name    = "${module.label.id}-masters.${var.private_hosted_zone_domain}"
  type    = "A"
  records = [ local.master_ip ]
  ttl     = 300
}