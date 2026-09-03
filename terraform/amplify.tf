# ============================================
# AWS AMPLIFY - Deploy LinkHub Frontend
# Region: us-east-1
# ============================================
variable "github_token" {
  description = "GitHub personal access token with repo write access for Amplify"
  sensitive   = true
}
# Create Amplify App
resource "aws_amplify_app" "linkhub" {
  name       = "linkhub-frontend"
  repository = "https://github.com/DevOps-Cloud-project-deployment/LINKHUB-WEBAPP-TERRAFORM-DEPLOYMENT-PROJECT.git"

  # GitHub personal access token with repo write access.
  # The target repository must allow deploy keys for Amplify to create the initial connection.
  access_token      = var.github_token
  platform          = "WEB"
  enable_basic_auth = false

 
build_spec = <<-EOT
  version: 1
  frontend:
    phases:
      build:
        commands:
          - echo "No build step needed - static site"
          - cp -r frontend/* ./
    artifacts:
      baseDirectory: .
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
  app_id            = aws_amplify_app.linkhub.id
  branch_name       = "master" # ← CHANGED to master
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