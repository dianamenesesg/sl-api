resource "aws_secretsmanager_secret" "nebius_api_key" {
  name        = "${var.app_name}/nebius-api-key"
  description = "Nebius AI API key for ${var.app_name}"
}

resource "aws_secretsmanager_secret_version" "nebius_api_key" {
  secret_id     = aws_secretsmanager_secret.nebius_api_key.id
  secret_string = var.nebius_api_key
}
