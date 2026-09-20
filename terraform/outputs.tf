output "runs_on_label" {
  description = "GitHub Actions のワークフローに書く runs-on の値"
  value       = "codebuild-${aws_codebuild_project.runner.name}-$${{ github.run_id }}-$${{ github.run_attempt }}"
}

output "connection_arn" {
  description = "GitHub App 接続の ARN。apply 直後は PENDING なのでコンソールで認可すること"
  value       = aws_codeconnections_connection.github.arn
}

output "connection_status" {
  description = "接続の状態。AVAILABLE になっていないとビルドが失敗する"
  value       = aws_codeconnections_connection.github.connection_status
}

output "log_group_name" {
  description = "ランナーのログが出力される CloudWatch Logs のロググループ"
  value       = aws_cloudwatch_log_group.runner.name
}
