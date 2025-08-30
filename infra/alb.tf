resource "aws_lb" "app" {
name = "${var.app_name}-alb"
internal = false
load_balancer_type = "application"
security_groups = [aws_security_group.alb_sg.id]
subnets = [for s in aws_subnet.public : s.id]
}


resource "aws_lb_target_group" "tg" {
name = "${var.app_name}-tg"
port = var.container_port
protocol = "HTTP"
vpc_id = aws_vpc.main.id
target_type = "ip"
health_check {
path = "/"
healthy_threshold = 2
unhealthy_threshold = 3
timeout = 5
interval = 30
matcher = "200"
}
}


resource "aws_lb_listener" "https" {
load_balancer_arn = aws_lb.app.arn
port = 443
protocol = "HTTPS"
ssl_policy = "ELBSecurityPolicy-2016-08"
certificate_arn = aws_acm_certificate.imported.arn


default_action {
type = "forward"
target_group_arn = aws_lb_target_group.tg.arn
}
}


# Optional HTTP -> HTTPS redirect
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}