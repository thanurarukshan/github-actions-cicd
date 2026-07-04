# ==============================================================================
# Task 3 — ECS Fargate Cluster, Task Definition, Security Group & Service
# ==============================================================================

# ── CloudWatch Log Group ──────────────────────────────────────────────────────
# Container stdout/stderr goes here — 7-day retention to control cost
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days
}

# ── ECS Cluster ───────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = var.ecs_cluster_name

  # Container Insights: publishes performance metrics (CPU, memory) per task
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ── Security Group for ECS Tasks ─────────────────────────────────────────────
resource "aws_security_group" "ecs_service" {
  name        = "${var.project_name}-ecs-sg"
  description = "Allows inbound on container port, all outbound"
  vpc_id      = data.aws_vpc.task1.id
}

resource "aws_vpc_security_group_ingress_rule" "ecs_app_in" {
  security_group_id = aws_security_group.ecs_service.id
  description       = "Allow HTTP on container port from anywhere"
  ip_protocol       = "tcp"
  from_port         = var.container_port
  to_port           = var.container_port
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ecs_all_out" {
  security_group_id = aws_security_group.ecs_service.id
  description       = "Allow all outbound (ECR pull, CloudWatch logs)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ── ECS Task Definition ───────────────────────────────────────────────────────
# Defines the container blueprint. The CI/CD pipeline will register new
# revisions of this definition on every deploy — Terraform only creates v1.
resource "aws_ecs_task_definition" "app" {
  family                   = var.container_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name      = var.container_name
    image     = "${aws_ecr_repository.app.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# ── ECS Service ───────────────────────────────────────────────────────────────
resource "aws_ecs_service" "app" {
  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.task1_public.ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = true # Required for Fargate in public subnets without NAT GW
  }

  # CRITICAL: ignore task_definition changes after initial creation.
  # The CI/CD pipeline (not Terraform) manages which image revision is deployed.
  # Without this, every terraform apply would reset the service to :latest.
  lifecycle {
    ignore_changes = [task_definition]
  }
}
