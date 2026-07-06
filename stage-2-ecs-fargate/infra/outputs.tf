# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (ALB)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (ECS tasks)"
  value       = aws_subnet.private[*].id
}

# -----------------------------------------------------------------------------
# ECR
# Pipeline uses this to tag and push the image before deploying.
# Example: docker tag fastapi-app <repository_url>:<version-tag>
# -----------------------------------------------------------------------------

output "ecr_repository_url" {
  description = "ECR repository URL - used by CI pipeline to push images"
  value       = aws_ecr_repository.app.repository_url
}

# -----------------------------------------------------------------------------
# ECS
# Pipeline uses cluster name and service name to trigger a deployment after
# pushing a new image and registering a new task definition revision.
# Example: aws ecs update-service --cluster <name> --service <name> --force-new-deployment
# -----------------------------------------------------------------------------

output "ecs_cluster_name" {
  description = "ECS cluster name - used by CI pipeline for deployments"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name - used by CI pipeline for deployments"
  value       = aws_ecs_service.app.name
}

output "ecs_task_definition_family" {
  description = "Task definition family name - used by CI pipeline to register new revisions"
  value       = aws_ecs_task_definition.app.family
}

# -----------------------------------------------------------------------------
# ALB
# DNS name of the load balancer - use app_url for the custom domain endpoint.
# -----------------------------------------------------------------------------

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer - entry point to the app"
  value       = aws_lb.main.dns_name
}

output "app_url" {
  description = "Application URL via custom domain"
  value       = "https://${var.domain_name}"
}

output "certificate_arn" {
  description = "ACM certificate ARN - referenced by the HTTPS listener"
  value       = aws_acm_certificate_validation.app.certificate_arn
}

output "sns_alarms_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications"
  value       = aws_sns_topic.alarms.arn
}

# -----------------------------------------------------------------------------
# IAM
# Paste the GitHub Actions role ARN into the workflow file so the pipeline
# can authenticate to AWS via OIDC without storing credentials.
# -----------------------------------------------------------------------------

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC authentication - add to workflow file"
  value       = aws_iam_role.github_actions.arn
}

# -----------------------------------------------------------------------------
# Secrets Manager
# Use this ARN to update the secret value before deploying the ECS service.
# aws secretsmanager put-secret-value --secret-id <arn> --secret-string '{"key":"value"}'
# -----------------------------------------------------------------------------

output "app_config_secret_arn" {
  description = "ARN of the app config secret in Secrets Manager - update values before first deploy"
  value       = aws_secretsmanager_secret.app_config.arn
}
