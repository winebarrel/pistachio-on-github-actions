# The pre-existing sandbox VPC.
# The private subnets route 0.0.0.0/0 through a NAT gateway created by hand
# (nat-090fed5068dabc939), which this Terraform does not manage.
data "aws_vpc" "sandbox" {
  filter {
    name   = "tag:Name"
    values = ["sandbox"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.sandbox.id]
  }

  filter {
    name   = "tag:Name"
    values = ["Private subnet-*"]
  }
}
