# CI/CD Pipeline (GitHub Actions) — Execution Steps

> These are your personal execution notes (gitignored). Follow each step in order.

---

## Overview

This task builds a GitHub Actions CI/CD pipeline that:
1. Triggers on push to `main`
2. Builds the Docker image from **Application** (reusing the same Dockerfile and app)
3. Tags the image with the Git commit SHA (immutable, traceable)
4. Pushes the image to **AWS ECR** — provisioned via Terraform
5. Deploys the updated image to **AWS ECS Fargate** — provisioned via Terraform
6. Adds a workflow status badge to the README

### Reusing Application
> The Application Docker project (`docker_containerization/Dockerfile` and `docker_containerization/app/`) is the application
> being built and pushed by this pipeline. No new application code is needed.

---

## Prerequisites

### 1. Infrastructure Must Be Running
The Terraform in this task reads Infrastructure's VPC and subnets via tags. Infrastructure must be deployed first.

```bash
cd terraform_aws_infrastructure && terraform output
# Confirm vpc_id and ec2_private_ips are shown
```

### 2. AWS CLI Configured
```bash
aws sts get-caller-identity
# Must return your Account ID — confirms credentials work
```

### 3. GitHub Repository Secrets
In your GitHub repo: **Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your IAM user's Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | Your IAM user's Secret Access Key |

Your IAM user needs these managed policies:
- `AmazonEC2ContainerRegistryFullAccess`
- `AmazonECS_FullAccess`

---

## Step 1: Provision Infrastructure with Terraform

```bash
cd github_actions_cicd/terraform

# Download providers (AWS ~6.x, null ~3.x)
terraform init

# Preview what will be created
terraform plan

# Create all resources
terraform apply
```

**Resources Terraform creates:**
- ECR repository (`devops-test-app`) with image scanning + lifecycle policy
- ECS Fargate cluster (`devops-cluster`)
- ECS task definition (initial revision using `:latest`)
- ECS service (`devops-test-service`, 1 replica)
- Security group allowing port 8080
- IAM execution role for ECS tasks
- CloudWatch log group (`/ecs/devops-test`)

**After apply, note the outputs:**
```
ecr_repository_url = "593793056080.dkr.ecr.us-east-1.amazonaws.com/devops-test-app"
ecs_cluster_name   = "devops-cluster"
ecs_service_name   = "devops-test-service"
container_name     = "devops-test-app"
aws_region         = "us-east-1"
```

**Screenshot opportunity:** Screenshot of the `terraform apply` output showing all resources created.

---

## Step 2: Create the GitHub Actions Workflow File

```bash
mkdir -p .github/workflows
```

Create `.github/workflows/docker-build-push.yml` — replace the values under `env:` with your
Terraform outputs from Step 1:

```yaml
# =============================================================================
# CI/CD Pipeline — Build, Push to ECR, Deploy to ECS Fargate
# Triggers on push to main. Uses Application Dockerfile.
# Infrastructure (ECR, ECS) is managed by github_actions_cicd/terraform/.
# =============================================================================

name: Build, Push to ECR and Deploy to ECS

on:
  push:
    branches: [main]

env:
  AWS_REGION:      us-east-1
  ECR_REPOSITORY:  devops-test-app
  ECS_CLUSTER:     devops-cluster
  ECS_SERVICE:     devops-test-service
  CONTAINER_NAME:  devops-test-app

jobs:
  build-push-deploy:
    name: Build, Push & Deploy
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      # ── AWS Authentication ─────────────────────────────────────────────────
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region:            ${{ env.AWS_REGION }}

      # ── ECR Login ─────────────────────────────────────────────────────────
      # Exchanges AWS creds for a temporary Docker auth token for ECR
      - name: Log in to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      # ── Docker BuildKit Setup ──────────────────────────────────────────────
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      # ── Build & Push to ECR ────────────────────────────────────────────────
      # Tags: sha-<full-commit-hash> (immutable) + latest (convenience)
      - name: Build and push image to ECR
        id: build-push
        uses: docker/build-push-action@v7
        with:
          context:    ./docker_containerization
          file:       ./docker_containerization/Dockerfile
          push:       true
          tags: |
            ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:latest
            ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:sha-${{ github.sha }}
          cache-from: type=gha
          cache-to:   type=gha,mode=max

      # ── Update Task Definition ─────────────────────────────────────────────
      # Downloads live task def and injects new image SHA tag into it.
      # Preserves all other config (CPU, memory, IAM roles, env vars).
      - name: Download current ECS task definition
        run: |
          aws ecs describe-task-definition \
            --task-definition ${{ env.CONTAINER_NAME }} \
            --query taskDefinition > /tmp/task-definition.json

      - name: Inject new image into task definition
        id: task-def
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: /tmp/task-definition.json
          container-name:  ${{ env.CONTAINER_NAME }}
          image:           ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:sha-${{ github.sha }}

      # ── Deploy to ECS ──────────────────────────────────────────────────────
      # Registers new task revision and triggers rolling deployment.
      # wait-for-service-stability=true: pipeline fails if container crashes on boot.
      - name: Deploy to ECS service
        uses: aws-actions/amazon-ecs-deploy-task-definition@v2
        with:
          task-definition:             ${{ steps.task-def.outputs.task-definition }}
          service:                     ${{ env.ECS_SERVICE }}
          cluster:                     ${{ env.ECS_CLUSTER }}
          wait-for-service-stability:  true
```

---

## Step 3: Add the Status Badge to README

After the workflow runs at least once, add this badge to your main `README.md`:

```markdown
[![Build, Push to ECR and Deploy to ECS](https://github.com/<YOUR_USERNAME>/<YOUR_REPO>/actions/workflows/docker-build-push.yml/badge.svg)](https://github.com/<YOUR_USERNAME>/<YOUR_REPO>/actions/workflows/docker-build-push.yml)
```

> **Easier:** Actions tab → click workflow → "..." menu → "Create status badge".

---

## Step 4: Push to GitHub and Trigger the Pipeline

```bash
git add .
git commit -m "feat: add CI/CD pipeline and ECR/ECS infrastructure"
git push origin main
```

---

## Step 5: Verify the Pipeline

### 5a. GitHub Actions
1. GitHub → **Actions** tab → watch the workflow run
2. All 7 steps should show green checkmarks

**Screenshot opportunity:** Workflow run page with all steps passing.

### 5b. Verify ECR Image Tags

```bash
aws ecr describe-images \
  --repository-name devops-test-app \
  --region us-east-1 \
  --output table
```
Expected: two tags — `latest` and `sha-<full-commit-hash>`.

**Screenshot opportunity:** ECR repository in AWS Console showing both image tags.

### 5c. Verify ECS Service & Get Public IP

```bash
# Check service is running
aws ecs describe-services \
  --cluster devops-cluster \
  --services devops-test-service \
  --region us-east-1 \
  --query "services[0].{Status:status,Running:runningCount,Desired:desiredCount}"

# Get the running task's public IP
TASK_ARN=$(aws ecs list-tasks \
  --cluster devops-cluster --service-name devops-test-service \
  --region us-east-1 --query "taskArns[0]" --output text)

ENI_ID=$(aws ecs describe-tasks \
  --cluster devops-cluster --tasks $TASK_ARN \
  --region us-east-1 \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
  --output text)

PUBLIC_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI_ID \
  --query "NetworkInterfaces[0].Association.PublicIp" --output text)

curl http://$PUBLIC_IP:8080
# Expected: Hello from DevOps Environment – Thanura
```

**Screenshot opportunity:** Terminal showing the curl response.

---

## File Summary

```
github_actions_cicd/
├── terraform/
│   ├── main.tf           # Provider + data sources (Infrastructure VPC/subnets)
│   ├── variables.tf
│   ├── terraform.tfvars  # (gitignored)
│   ├── ecr.tf            # ECR repo + lifecycle policy
│   ├── iam.tf            # ECS task execution IAM role
│   ├── ecs.tf            # Cluster, task def, service, security group
│   └── outputs.tf
.github/
└── workflows/
    └── docker-build-push.yml
```

---

## Destroy (Cleanup)

```bash
# First scale down the ECS service (required before Terraform destroy)
aws ecs update-service \
  --cluster devops-cluster \
  --service devops-test-service \
  --desired-count 0 \
  --region us-east-1

# Wait ~30 seconds for tasks to drain, then destroy everything
cd github_actions_cicd/terraform
terraform destroy
```

> **Note:** The ECR lifecycle policy keeps only the last 10 images.
> `terraform destroy` deletes the repository and all images inside it.

---

## Troubleshooting

| Issue | Solution |
|---|---|
| `terraform plan` fails — VPC not found | Ensure Infrastructure is deployed and the `project_name` variable matches exactly |
| ECR login fails in workflow | Verify `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets; check IAM permissions |
| ECS deploy times out | Check container logs: CloudWatch → Log groups → `/ecs/devops-test` |
| Task fails health check | Verify container port 8080 is exposed in Dockerfile and security group allows it |
| Badge shows "no status" | Workflow must run at least once before the badge activates |
