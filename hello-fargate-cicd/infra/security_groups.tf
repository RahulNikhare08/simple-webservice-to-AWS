# ALB SG - allow 80/443 from anywhere
resource "aws_security_group" "alb_sg" {
name = "${var.app_name}-alb-sg"
description = "ALB security group"
vpc_id = aws_vpc.main.id


ingress {
from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
ingress {
from_port = 443
to_port = 443
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
}


# ECS task SG - allow from ALB only
resource "aws_security_group" "ecs_sg" {
name = "${var.app_name}-ecs-sg"
description = "ECS tasks"
vpc_id = aws_vpc.main.id


ingress {
from_port = var.container_port
to_port = var.container_port
protocol = "tcp"
security_groups = [aws_security_group.alb_sg.id]
}
egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
}