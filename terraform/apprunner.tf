resource "aws_apprunner_service" "app" {
  service_name = var.app_name

  source_configuration {
    # Allows App Runner to pull the image from the private ECR repository
    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_access.arn
    }

    image_repository {
      image_identifier      = "${aws_ecr_repository.app.repository_url}:latest"
      image_repository_type = "ECR"

      image_configuration {
        port = "8080"

        # Pulls the secret value from Secrets Manager and injects it as an env var.
        # The container sees it as a normal NEBIUS_API_KEY environment variable.
        runtime_environment_secrets = {
          NEBIUS_API_KEY = aws_secretsmanager_secret.nebius_api_key.arn
        }
      }
    }

    # Set to true if you want App Runner to redeploy automatically
    # every time a new image is pushed to ECR with the :latest tag.
    auto_deployments_enabled = false
  }

  instance_configuration {
    instance_role_arn = aws_iam_role.apprunner_instance.arn
    cpu               = var.cpu
    memory            = var.memory
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/health"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 3
  }
}
