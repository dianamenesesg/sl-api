output "app_url" {
  description = "Public HTTPS endpoint for the API"
  value       = "https://${aws_apprunner_service.app.service_url}"
}

output "ecr_repository_url" {
  description = "ECR URL — use this to tag and push your Docker image"
  value       = aws_ecr_repository.app.repository_url
}
