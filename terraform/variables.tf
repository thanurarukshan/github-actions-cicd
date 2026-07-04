# ==============================================================================
# Task 3 — Variables
# ==============================================================================

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resource names"
  type        = string
  default     = "devops-test"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "devops-test-app"
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "devops-cluster"
}

variable "ecs_service_name" {
  description = "Name of the ECS service"
  type        = string
  default     = "devops-test-service"
}

variable "container_name" {
  description = "Name of the container inside the task definition"
  type        = string
  default     = "devops-test-app"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "task_cpu" {
  description = "CPU units for the Fargate task (256 = 0.25 vCPU)"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Memory (MB) for the Fargate task"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Number of running ECS task replicas"
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "Days to retain ECS container logs in CloudWatch"
  type        = number
  default     = 7
}
