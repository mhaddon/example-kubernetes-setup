data "aws_ami" "centos7" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "product-code"
    values = ["cvugziknvmxgqna9noibqnnsy"] #https://wiki.centos.org/Cloud/AWS#AWS_Provided_Marketplace_Images_with_Updates
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}