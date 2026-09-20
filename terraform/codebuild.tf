resource "aws_security_group" "codebuild" {
  name        = "gha-runner-codebuild"
  description = "CodeBuild GitHub Actions runner"
  vpc_id      = data.aws_vpc.sandbox.id
}

# Outbound is wide open, through the NAT gateway: the runner has to reach
# GitHub and download the pistachio .deb.
resource "aws_vpc_security_group_egress_rule" "codebuild" {
  security_group_id = aws_security_group.codebuild.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound"
}

resource "aws_cloudwatch_log_group" "runner" {
  name              = "/aws/codebuild/gha-runner"
  retention_in_days = 14
}

# The GitHub App (AWS Connector for GitHub) connection.
# It stays PENDING right after terraform apply. Finish it by hand from
# Developer Tools > Settings > Connections in the console:
# "Update pending connection", then install and authorize the GitHub App.
resource "aws_codeconnections_connection" "github" {
  name          = "gha-runner"
  provider_type = "GitHub"
}

# Register the connection as the account level GitHub credential.
# Note: there can be only one per account, region and server type.
resource "aws_codebuild_source_credential" "github" {
  auth_type   = "CODECONNECTIONS"
  server_type = "GITHUB"
  token       = aws_codeconnections_connection.github.arn
}

resource "aws_codebuild_project" "runner" {
  name          = "gha-runner"
  description   = "GitHub Actions self-hosted runner on AWS CodeBuild"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 60

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:8.0"
    type         = "LINUX_CONTAINER"

    # Set to true to run docker build and the like
    privileged_mode = false

    # Where pistachio connects. These reach the runner job as plain
    # environment variables, so anything the workflow runs can read them.
    environment_variable {
      name  = "PISTA_CONN_STR"
      value = "postgres://${aws_db_instance.postgres.username}@${aws_db_instance.postgres.endpoint}/${aws_db_instance.postgres.db_name}"
    }

    # The master password RDS put in Secrets Manager
    environment_variable {
      name  = "PISTA_PASSWORD"
      value = "${aws_db_instance.postgres.master_user_secret[0].secret_arn}:password"
      type  = "SECRETS_MANAGER"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/winebarrel/pistachio-on-github-actions.git"
    git_clone_depth = 1

    # CodeBuild replaces this buildspec when it starts a GitHub Actions
    # runner, so it never runs. It is here only because a project needs one.
    buildspec = yamlencode({
      version = "0.2"
      phases = {
        build = {
          commands = ["echo 'This buildspec is replaced by the GitHub Actions runner.'"]
        }
      }
    })
  }

  # In the VPC so it can reach RDS. This also sends GitHub-bound traffic
  # through the VPC, which is why the private subnets need a NAT gateway.
  vpc_config {
    vpc_id             = data.aws_vpc.sandbox.id
    subnets            = data.aws_subnets.private.ids
    security_group_ids = [aws_security_group.codebuild.id]
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.runner.name
    }
  }

  depends_on = [aws_codebuild_source_credential.github]
}

# The webhook that starts a build - that is, a runner - per queued workflow job
resource "aws_codebuild_webhook" "runner" {
  project_name = aws_codebuild_project.runner.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "WORKFLOW_JOB_QUEUED"
    }
  }
}
