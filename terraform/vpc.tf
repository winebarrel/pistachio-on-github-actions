# 既存の sandbox VPC を参照する。
# プライベートサブネットの 0.0.0.0/0 は手動で作成した NAT Gateway
# (nat-090fed5068dabc939) を向いている。Terraform の管理外。
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
