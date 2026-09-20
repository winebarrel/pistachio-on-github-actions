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

    # Guard against the confused deputy problem. The ARN is written out
    # because the project refers to this role, and referring back would
    # make the Terraform graph circular.
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

  # Needed to get a token from the GitHub App connection
  statement {
    sid    = "CodeConnections"
    effect = "Allow"

    actions = [
      "codeconnections:GetConnection",
      "codeconnections:GetConnectionToken",
    ]

    resources = [aws_codeconnections_connection.github.arn]
  }

  # ENI handling for builds inside the VPC. The Describe actions cannot be
  # scoped to a resource.
  statement {
    sid    = "VpcNetworkInterface"
    effect = "Allow"

    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "VpcNetworkInterfacePermission"
    effect = "Allow"

    actions = ["ec2:CreateNetworkInterfacePermission"]

    resources = ["arn:aws:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:network-interface/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"
      values   = ["codebuild.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "ec2:Subnet"
      values   = [for id in data.aws_subnets.private.ids : "arn:aws:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:subnet/${id}"]
    }
  }

  # Needed to resolve PISTA_PASSWORD from Secrets Manager
  statement {
    sid    = "ReadMasterUserSecret"
    effect = "Allow"

    actions = ["secretsmanager:GetSecretValue"]

    resources = [aws_db_instance.postgres.master_user_secret[0].secret_arn]
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
