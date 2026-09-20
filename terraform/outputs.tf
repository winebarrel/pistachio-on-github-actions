output "runs_on_label" {
  description = "The runs-on value to put in a GitHub Actions workflow"
  value       = "codebuild-${aws_codebuild_project.runner.name}-$${{ github.run_id }}-$${{ github.run_attempt }}"
}

output "connection_arn" {
  description = "ARN of the GitHub App connection. It is PENDING right after apply; authorize it in the console"
  value       = aws_codeconnections_connection.github.arn
}

output "connection_status" {
  description = "Connection status. Builds fail unless this is AVAILABLE"
  value       = aws_codeconnections_connection.github.connection_status
}

output "log_group_name" {
  description = "CloudWatch Logs group the runner writes to"
  value       = aws_cloudwatch_log_group.runner.name
}
