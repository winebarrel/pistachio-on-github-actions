resource "aws_cloudwatch_log_group" "runner" {
  name              = "/aws/codebuild/gha-runner"
  retention_in_days = 14
}

# GitHub App (AWS Connector for GitHub) との接続。
# terraform apply 直後は PENDING のままなので、コンソールの
# Developer Tools > Settings > Connections から "Update pending connection" で
# GitHub App のインストール/認可を手動で済ませる必要がある。
resource "aws_codeconnections_connection" "github" {
  name          = "gha-runner"
  provider_type = "GitHub"
}

# アカウントレベルの GitHub 認証情報として CodeConnections の接続を登録する。
# 注意: アカウント + リージョン + サーバータイプごとに 1 つしか持てない。
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

    # docker build などを動かすなら true
    privileged_mode = false
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/winebarrel/pistachio-on-github-actions.git"
    git_clone_depth = 1

    # GitHub Actions ランナーとして起動する場合、buildspec は CodeBuild 側で
    # 上書きされるため実際には使われない。プロジェクト作成に必要なので置いておく。
    buildspec = yamlencode({
      version = "0.2"
      phases = {
        build = {
          commands = ["echo 'This buildspec is replaced by the GitHub Actions runner.'"]
        }
      }
    })
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.runner.name
    }
  }

  depends_on = [aws_codebuild_source_credential.github]
}

# workflow_job(queued) を受けてビルド = ランナーを起動する Webhook
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
