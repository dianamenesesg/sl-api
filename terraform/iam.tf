# --- Access role ---
# App Runner assumes this role to pull images from ECR.
# Uses the AWS-managed policy designed exactly for this purpose.

resource "aws_iam_role" "apprunner_ecr_access" {
  name = "${var.app_name}-apprunner-ecr-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "build.apprunner.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr_access" {
  role       = aws_iam_role.apprunner_ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# --- Instance role ---
# The running container assumes this role.
# Grants read access to the Nebius API key secret only.

resource "aws_iam_role" "apprunner_instance" {
  name = "${var.app_name}-apprunner-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "tasks.apprunner.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "apprunner_read_secret" {
  name = "${var.app_name}-read-nebius-secret"
  role = aws_iam_role.apprunner_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.nebius_api_key.arn
    }]
  })
}
