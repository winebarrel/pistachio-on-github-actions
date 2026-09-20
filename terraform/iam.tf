data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    # 他アカウント経由の混乱した代理を防ぐ。
    # プロジェクト側がこのロールを参照するので、循環参照を避けて ARN は直書き。
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:codebuild:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:project/gha-runner"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "gha-runner-codebuild"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      aws_cloudwatch_log_group.runner.arn,
      "${aws_cloudwatch_log_group.runner.arn}:*",
    ]
  }

  # GitHub App 接続からトークンを受け取るために必要
  statement {
    sid    = "CodeConnections"
    effect = "Allow"

    actions = [
      "codeconnections:GetConnection",
      "codeconnections:GetConnectionToken",
    ]

    resources = [aws_codeconnections_connection.github.arn]
  }

  statement {
    sid    = "CodeBuildReports"
    effect = "Allow"

    actions = [
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases",
      "codebuild:BatchPutCodeCoverages",
    ]

    resources = [
      "arn:aws:codebuild:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:report-group/gha-runner-*",
    ]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "gha-runner-codebuild"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
}
