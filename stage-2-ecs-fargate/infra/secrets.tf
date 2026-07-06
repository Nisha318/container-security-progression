# KMS Key for Secrets Manager

resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager - ${var.project_name}-${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-${var.environment}-secrets-kms-key"
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}-${var.environment}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# App Config Secret
resource "aws_secretsmanager_secret" "app_config" {
  name        = "${var.project_name}/${var.environment}/app-config"
  description = "Application configuration for ${var.project_name} ${var.environment}"
  kms_key_id  = aws_kms_key.secrets.arn

  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-app-config"
  }
}

resource "aws_secretsmanager_secret_version" "app_config" {
  secret_id = aws_secretsmanager_secret.app_config.id

  secret_string = jsonencode({
    APP_ENV    = var.environment
    SECRET_KEY = "replace-before-deploy"
    # API_KEY    = "replace-before-deploy"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
