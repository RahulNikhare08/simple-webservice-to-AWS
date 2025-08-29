resource "random_pet" "suffix" {}


resource "tls_private_key" "this" {
algorithm = "RSA"
rsa_bits = 2048
}


resource "tls_self_signed_cert" "this" {
private_key_pem = tls_private_key.this.private_key_pem
subject {
common_name = "${var.app_name}.example.local"
organization = "Demo"
}
validity_period_hours = 8760
allowed_uses = [
"key_encipherment",
"digital_signature",
"server_auth"
]
}


resource "aws_acm_certificate" "imported" {
private_key = tls_private_key.this.private_key_pem
certificate_body = tls_self_signed_cert.this.cert_pem
certificate_chain = tls_self_signed_cert.this.cert_pem
}