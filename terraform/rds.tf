resource "aws_db_subnet_group" "postgres" {
  name       = "pistachio-demo"
  subnet_ids = data.aws_subnets.private.ids
}

resource "aws_security_group" "postgres" {
  name        = "pistachio-demo-postgres"
  description = "pistachio demo PostgreSQL"
  vpc_id      = data.aws_vpc.sandbox.id
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_codebuild" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = aws_security_group.codebuild.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from the GitHub Actions runner"
}

resource "aws_db_instance" "postgres" {
  identifier = "pistachio-demo"

  engine = "postgres"
  # Let AWS pick the minor version (auto_minor_version_upgrade)
  engine_version = "18"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "pistachio"
  username = "postgres"

  # RDS generates the password and manages it in Secrets Manager,
  # so it never lands in the Terraform state.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]
  publicly_accessible    = false

  # Minimal settings: this is a demo database
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
}
