# ============================================
# Outputs - Shows important information after deployment
# ============================================

# Server IP address
output "server_ip" {
  description = "Public IP address of LinkHub server"
  value       = aws_eip.linkhub.public_ip
}

# SSH connection command
output "ssh_command" {
  description = "Command to SSH into the server"
  value       = "ssh -i ../linkhub-key.pem ec2-user@${aws_eip.linkhub.public_ip}"
}

# Website URL
output "website_url" {
  description = "URL to access LinkHub API"
  value       = "http://${aws_eip.linkhub.public_ip}:5000"
}

# API endpoint
output "api_endpoint" {
  description = "API endpoint for LinkHub"
  value       = "http://${aws_eip.linkhub.public_ip}:5000"
}

# Deployment summary
output "deployment_summary" {
  description = "Summary of deployed resources"
  value       = <<-EOT
╔══════════════════════════════════════════════════════════════════╗
║                    LINKHUB - DEPLOYMENT SUMMARY                   ║
╚══════════════════════════════════════════════════════════════════╝

📍 SERVER:
   IP Address: ${aws_eip.linkhub.public_ip}
   SSH Command: ssh -i ../linkhub-key.pem ec2-user@${aws_eip.linkhub.public_ip}

🌐 API:
   URL: http://${aws_eip.linkhub.public_ip}:5000
   Health Check: http://${aws_eip.linkhub.public_ip}:5000/health

🔑 KEY FILE:
   Location: ../linkhub-key.pem
   Permission: 0600 (set automatically)

╔══════════════════════════════════════════════════════════════════╗
║  NEXT STEPS:                                                     ║
║  1. Save the key file (linkhub-key.pem) somewhere safe          ║
║  2. Test API: curl http://${aws_eip.linkhub.public_ip}:5000     ║
║  3. SSH to server to check logs                                 ║
╚══════════════════════════════════════════════════════════════════╝
EOT
}
# output "private_key" {
#   value = tls_private_key.linkhub.private_key_pem
#   sensitive = true
# }