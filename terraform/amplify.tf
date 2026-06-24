# ============================================
# AWS AMPLIFY - Deploy LinkHub Frontend
# Region: us-east-1
# ============================================

# Create Amplify App
resource "aws_amplify_app" "linkhub" {
  name       = "linkhub-frontend"
  repository = "https://github.com/DevOps-Cloud-project-deployment/LINKHUB-WEBAPP-TERRAFORM-DEPLOYMENT-PROJECT.git"

  # Build settings for static site
  build_spec = <<-EOT
    version: 1
    frontend:
      phases:
        build:
          commands:
            - echo "No build step needed - static site"
      artifacts:
        baseDirectory: frontend
        files:
          - '**/*'
  EOT

  # Environment variables
  environment_variables = {
    API_URL = "http://${aws_eip.linkhub.public_ip}:5000"
  }

  tags = {
    Name        = "linkhub-frontend"
    Environment = "production"
    Project     = "linkhub"
  }
}

# Create a branch (master)
resource "aws_amplify_branch" "master" {
  app_id      = aws_amplify_app.linkhub.id
  branch_name = "master"          # ← CHANGED to master
  enable_auto_build = true

  tags = {
    Name = "linkhub-master-branch"
  }
}

# Output the Amplify URL
output "amplify_url" {
  description = "Amplify hosted URL"
  value       = "https://master.${aws_amplify_app.linkhub.default_domain}"
}