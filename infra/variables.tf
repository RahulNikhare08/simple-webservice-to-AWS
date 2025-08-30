variable "region" {
  type    = string
  default = "us-east-1"
}

variable "app_name" {
  type    = string
  default = "hello-fargate"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "container_port" {
  type    = number
  default = 3000
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "image_repo_url" {
  type        = string
  description = "ECR repo URL (account.dkr.ecr.region.amazonaws.com/repo)"
}

variable "image_tag" {
  type        = string
  description = "Container image tag (e.g., Git SHA)"
  default     = "latest"
}

variable "db_connection_string" {
  type        = string
  description = "Dummy DB URL"
  default     = "postgres://user:pass@host:5432/db"
}