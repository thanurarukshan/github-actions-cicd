# ==============================================================================
# ECR Repository
# ==============================================================================

resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE" # Required: CI/CD overwrites :latest on every push

  # Automatically scan every pushed image for OS/package CVEs at no extra cost
  image_scanning_configuration {
    scan_on_push = true
  }

  # AES256 is free; KMS is available for stricter compliance requirements
  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Lifecycle policy: keep only the last 10 images to control registry storage costs
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire images beyond the last 10"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
