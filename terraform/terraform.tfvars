# ==============================================================================
# Task 3 — Variable Overrides
# This file is gitignored — never commit it.
# ==============================================================================

aws_region          = "us-east-1"
project_name        = "devops-test"
environment         = "dev"
ecr_repository_name = "devops-test-app"
ecs_cluster_name    = "devops-cluster"
ecs_service_name    = "devops-test-service"
container_name      = "devops-test-app"
container_port      = 8080
task_cpu            = "256"
task_memory         = "512"
desired_count       = 1
log_retention_days  = 7
