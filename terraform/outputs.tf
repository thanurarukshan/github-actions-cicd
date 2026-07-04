# ==============================================================================
# Task 3 — Outputs
# ==============================================================================

output "ecr_repository_url" {
  description = "Full ECR URI — paste this into the GitHub Actions workflow env vars"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.app.name
}

output "ecs_cluster_name" {
  description = "ECS cluster name — used in the GitHub Actions deploy step"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name — used in the GitHub Actions deploy step"
  value       = aws_ecs_service.app.name
}

output "container_name" {
  description = "Container name — must match the container_name in the workflow"
  value       = var.container_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for ECS container logs"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
