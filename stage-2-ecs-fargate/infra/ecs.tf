# -----------------------------------------------------------------------------
# KMS Key for CloudWatch Logs
# CloudWatch Logs requires an explicit key policy granting the service
# permission to use the key - the execution role's KMS permissions are not
# enough. This key policy adds that grant.
# -----------------------------------------------------------------------------

resource "aws_kms_key" "logs" {
  description             = "KMS key for CloudWatch Logs - ${var.project_name}-${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-logs-kms-key"
  }
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.project_name}-${var.environment}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# ECS sends container stdout/stderr here via the awslogs log driver.
# The log group name must match what is referenced in the task definition.
# 30-day retention keeps logs available for incident investigation without
# accumulating indefinitely.
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-logs"
  }
}

# -----------------------------------------------------------------------------
# ECS Cluster
# A logical boundary for tasks and services. Container Insights enabled
# for CloudWatch metrics on CPU, memory, network, and task health.
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# -----------------------------------------------------------------------------
# Task Definition
# The blueprint ECS uses every time it starts a container. Security settings
# carried forward from Stage 1 (non-root, read-only filesystem) are enforced
# here at the orchestration layer, not just in the Dockerfile.
#
# Image tag: the task definition is initialized with :latest as a placeholder.
# The CI pipeline registers a new task definition revision on each deploy,
# using the version tag as the image tag. The ECS service lifecycle block
# (ignore_changes = [task_definition]) ensures Tofu does not overwrite
# pipeline-managed revisions on subsequent applies.
# -----------------------------------------------------------------------------

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-${var.environment}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = var.project_name
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.app_port
          protocol      = "tcp"
        }
      ]

      # Security settings - mirror and enforce what was set in the Dockerfile
      readonlyRootFilesystem = true
      privileged             = false
      user                   = "65532"

      linuxParameters = {
        initProcessEnabled = true
        capabilities = {
          # Drop all Linux capabilities from the container.
          drop = ["ALL"]
          add  = []
        }
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      # Secrets injected by ECS at startup using the execution role.
      # The app reads these as normal environment variables.
      # The :key:: syntax extracts a specific key from a JSON secret.
      secrets = [
        {
          name      = "APP_ENV"
          valueFrom = "${aws_secretsmanager_secret.app_config.arn}:APP_ENV::"
        },
        {
          name      = "SECRET_KEY"
          valueFrom = "${aws_secretsmanager_secret.app_config.arn}:SECRET_KEY::"
        }

        # Additional secrets follow the same pattern. Each key in the JSON secret
        # maps to a separate entry using the :key:: syntax to extract individual
        # fields from the JSON object stored in Secrets Manager.
        # {
        #   name      = "API_KEY"
        #   valueFrom = "${aws_secretsmanager_secret.app_config.arn}:API_KEY::"
        # }
      ]

      healthCheck = {
        command     = ["CMD", "python3", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 15
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-${var.environment}-task"
  }
}

# -----------------------------------------------------------------------------
# Application Load Balancer
# Internet-facing ALB in public subnets. ECS tasks stay in private subnets
# and are never directly reachable from the internet.
#
# Prevents HTTP request smuggling by rejecting malformed headers.
# -----------------------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  drop_invalid_header_fields = true
  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# Target group uses IP target type - required for Fargate awsvpc networking.
# Unlike EC2, Fargate tasks register by IP address, not instance ID.
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-${var.environment}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-tg"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.app.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# HTTP redirects permanently to HTTPS - no traffic served over plain HTTP
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# -----------------------------------------------------------------------------
# ECS Service
# Keeps the desired number of tasks running and connects them to the ALB.
# The service monitors task health via the ALB health check and replaces
# tasks that fail.
#
# lifecycle.ignore_changes = [task_definition] is intentional.
# The CI pipeline manages task definition revisions after initial deploy.
# Without this, every tofu apply would roll back to the Tofu-managed
# revision rather than the latest pipeline-deployed revision.
# -----------------------------------------------------------------------------

resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.project_name
    container_port   = var.app_port
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 30

  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [
    aws_lb_listener.https,
    aws_iam_role_policy.task_execution
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-service"
  }
}
