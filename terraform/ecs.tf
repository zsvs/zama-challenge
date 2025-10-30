# CloudWatch log group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = 7
}

# ECS cluster
resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"
}

# IAM roles
data "aws_iam_policy_document" "task_exec_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "task_execution" {
  name               = "${var.name_prefix}-task-exec"
  assume_role_policy = data.aws_iam_policy_document.task_exec_assume.json
}

resource "aws_iam_role_policy_attachment" "task_exec_attach" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom policy for task execution role to read SSM parameters
data "aws_iam_policy_document" "task_exec_ssm" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = [aws_ssm_parameter.api_key.arn]
  }
}

resource "aws_iam_policy" "task_exec_ssm" {
  name   = "${var.name_prefix}-task-exec-ssm"
  policy = data.aws_iam_policy_document.task_exec_ssm.json
}

resource "aws_iam_role_policy_attachment" "task_exec_ssm_attach" {
  role       = aws_iam_role.task_execution.name
  policy_arn = aws_iam_policy.task_exec_ssm.arn
}

# Task role for reading SSM parameter
resource "aws_iam_role" "task_role" {
  name               = "${var.name_prefix}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_exec_assume.json
}

data "aws_iam_policy_document" "ssm_read" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [aws_ssm_parameter.api_key.arn]
  }
}
resource "aws_iam_policy" "ssm_read" {
  name   = "${var.name_prefix}-ssm-read"
  policy = data.aws_iam_policy_document.ssm_read.json
}
resource "aws_iam_role_policy_attachment" "task_role_attach" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.ssm_read.arn
}

# Security groups
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB ingress"
  vpc_id      = data.aws_vpc.default.id
  tags = {
    "name"      = "zama-alb-sg"
    "terraform" = "true"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_allow_https" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_egress" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_security_group" "ecs" {
  name        = "${var.name_prefix}-ecs-sg"
  description = "ECS tasks"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "ecs_allow_alb" {
  security_group_id = aws_security_group.ecs.id

  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb.id

}

resource "aws_vpc_security_group_egress_rule" "ecs_egress" {
  security_group_id = aws_security_group.ecs.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# ALB + TG + Listener
resource "aws_lb" "this" {
  name               = replace("${var.name_prefix}-alb", "_", "-")
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default_public.ids
}

resource "aws_lb_target_group" "this" {
  name        = replace("${var.name_prefix}-tg", "_", "-")
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.default.id

  health_check {
    enabled  = true
    path     = "/readyz"
    matcher  = "200-399"
    interval = 15
    timeout  = 5
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

locals {
  api_image   = "${aws_ecr_repository.api.repository_url}:${var.image_tag}"
  nginx_image = "${aws_ecr_repository.nginx.repository_url}:${var.image_tag}"
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.name_prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = aws_iam_role.task_role.arn
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([
    {
      "name" : "api",
      "image" : local.api_image,
      "essential" : true,
      "portMappings" : [{ "containerPort" : 8080, "hostPort" : 8080, "protocol" : "tcp" }],
      "environment" : [
        { "name" : "REQUIRE_API_KEY", "value" : "false" }
      ],
      "logConfiguration" : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : aws_cloudwatch_log_group.ecs.name,
          "awslogs-region" : var.region,
          "awslogs-stream-prefix" : "api"
        }
      }
    },
    {
      "name" : "nginx",
      "image" : local.nginx_image,
      "essential" : true,
      "portMappings" : [{ "containerPort" : 80, "hostPort" : 80, "protocol" : "tcp" }],
      "environment" : [
        { "name" : "API_HOST", "value" : "localhost" },
        { "name" : "API_PORT", "value" : "8080" }
      ],
      "secrets" : [
        { "name" : "API_KEY", "valueFrom" : aws_ssm_parameter.api_key.arn }
      ],
      "logConfiguration" : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : aws_cloudwatch_log_group.ecs.name,
          "awslogs-region" : var.region,
          "awslogs-stream-prefix" : "nginx"
        }
      }
    }
  ])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

resource "aws_ecs_service" "this" {
  name            = "${var.name_prefix}-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default_public.ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "nginx"
    container_port   = 80
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  depends_on = [aws_lb_listener.http]
}
