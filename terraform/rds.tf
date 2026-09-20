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

resource "aws_db_subnet_group" "postgres" {
  name       = "pistachio-demo"
  subnet_ids = data.aws_subnets.private.ids
}

# ingress は CodeBuild を VPC に入れるときに追加する。
# 現時点ではどこからも接続できない。
resource "aws_security_group" "postgres" {
  name        = "pistachio-demo-postgres"
  description = "pistachio demo PostgreSQL"
  vpc_id      = data.aws_vpc.sandbox.id
}

resource "aws_db_instance" "postgres" {
  identifier = "pistachio-demo"

  engine = "postgres"
  # マイナーバージョンは AWS 任せ (auto_minor_version_upgrade)
  engine_version = "18"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "pistachio"
  username = "postgres"

  # パスワードは RDS が生成して Secrets Manager で管理する。
  # tfstate にパスワードが残らない。
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]
  publicly_accessible    = false

  # デモ用なので最小構成
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
}
