resource "aws_ecs_cluster" "this" {
  name = "${var.app_name}-cluster"
}

resource "aws_iam_role" "task_exec" {
  name = "${var.app_name}-task-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_exec_attach" {
  role       = aws_iam_role.task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# allow reading secrets
resource "aws_iam_policy" "secrets_read" {
  name        = "${var.app_name}-secrets-read"
  description = "Allow read of Secrets Manager"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["secretsmanager:GetSecretValue"],
      Resource = [aws_secretsmanager_secret.db.arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "exec_secrets" {
  role       = aws_iam_role.task_exec.name
  policy_arn = aws_iam_policy.secrets_read.arn
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_exec.arn

  container_definitions = jsonencode([
    {
      name      = var.app_name,
      image     = "${var.image_repo_url}:${var.image_tag}",
      essential = true,
      portMappings = [{ containerPort = var.container_port, hostPort = var.container_port, protocol = "tcp" }],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = var.app_name
        }
      },
      secrets = [
        {
          name      = "DB_URL",
          valueFrom = aws_secretsmanager_secret.db.arn
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "${var.app_name}-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [for s in aws_subnet.public : s.id]
    assign_public_ip = true
    security_groups = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = var.app_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.https]
}
