# Simple CloudWatch dashboard and an alarm for ALB 5xx
resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.name_prefix}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        "type" : "metric",
        "width" : 24, "height" : 6, "x" : 0, "y" : 0,
        "properties" : {
          "title" : "ALB 5xx + Target 5xx",
          "region" : var.region,
          "metrics" : [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.this.arn_suffix],
            [".", "HTTPCode_Target_5XX_Count", "TargetGroup", aws_lb_target_group.this.arn_suffix, "LoadBalancer", aws_lb.this.arn_suffix]
          ],
          "stat" : "Sum", "period" : 60, "view" : "timeSeries", "stacked" : false
        }
      },
      {
        "type" : "metric",
        "width" : 24, "height" : 6, "x" : 0, "y" : 6,
        "properties" : {
          "title" : "ECS CPUUtilization (Service)",
          "region" : var.region,
          "metrics" : [
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.this.name, "ClusterName", aws_ecs_cluster.this.name]
          ],
          "stat" : "Average", "period" : 60, "view" : "timeSeries", "stacked" : false
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name_prefix}-alb-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "High 5xx from targets behind ALB"
  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.this.arn_suffix
  }
}
