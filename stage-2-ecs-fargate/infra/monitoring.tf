# -----------------------------------------------------------------------------
# SNS Topic for Alarm Notifications
# All CloudWatch alarms in this project route to this topic.
# Additional subscriptions can be added here for other protocols.
# The alarm_email variable controls whether an email subscription is created.
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-${var.environment}-alarms"

  tags = {
    Name = "${var.project_name}-${var.environment}-alarms"
  }
}

# -----------------------------------------------------------------------------
# Email Subscription
# Only created if alarm_email variable is set. After tofu apply, AWS sends a
# confirmation email - the subscription is inactive until you click the link.
# Alarms will not deliver until confirmation is complete.
# -----------------------------------------------------------------------------

resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# -----------------------------------------------------------------------------
# Alarm: ECS Running Task Count
# Fires when the number of running tasks drops below the desired count of 1.
# This catches service crashes, failed deployments, and task restart loops.
#
# Metric source: ECS ContainerInsights (requires containerInsights = "enabled"
# on the cluster, which is set in ecs.tf).
#
# treat_missing_data = "breaching" means if no data is received (e.g. the
# cluster itself is gone), the alarm fires rather than staying OK.
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "ecs_task_count" {
  alarm_name          = "${var.project_name}-${var.environment}-task-count-low"
  alarm_description   = "ECS running task count is below desired count of 1"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Name = "${var.project_name}-${var.environment}-task-count-alarm"
  }
}

# -----------------------------------------------------------------------------
# Alarm: ALB 5xx Errors
# Fires when the ALB returns more than 5 server-side errors in a 60-second
# window over 2 consecutive periods. This catches application errors,
# unhandled exceptions, and downstream dependency failures.
#
# treat_missing_data = "notBreaching" because no 5xx errors is the healthy
# baseline - missing data (no traffic) should not trigger an alarm.
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx"
  alarm_description   = "ALB is returning elevated 5xx errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-5xx-alarm"
  }
}

# -----------------------------------------------------------------------------
# Alarm: ALB Unhealthy Host Count
# Fires when any ECS task fails the ALB health check. This is the earliest
# signal that a task is unhealthy - often fires before the task count alarm
# because ECS takes time to replace unhealthy tasks.
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-${var.environment}-unhealthy-hosts"
  alarm_description   = "One or more ECS tasks are failing ALB health checks"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Name = "${var.project_name}-${var.environment}-unhealthy-hosts-alarm"
  }
}
