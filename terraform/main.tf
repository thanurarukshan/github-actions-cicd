# ==============================================================================
# CI/CD Infrastructure
# Provisions: ECR repository, ECS Fargate cluster, task definition, service
# Reuses:     VPC and subnets from Infrastructure (discovered via data sources)
# ==============================================================================

terraform {
  required_version = ">= 1.15.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Task        = "task-3-cicd"
    }
  }
}

# ── Reuse Infrastructure Networking (discovered by tag — no shared state required) ───

data "aws_vpc" "task1" {
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

data "aws_subnets" "task1_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.task1.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}
