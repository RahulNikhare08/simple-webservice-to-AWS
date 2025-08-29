resource "aws_secretsmanager_secret" "db" {
name = "${var.app_name}/db-url"
}


resource "aws_secretsmanager_secret_version" "dbv" {
secret_id = aws_secretsmanager_secret.db.id
secret_string = var.db_connection_string
}