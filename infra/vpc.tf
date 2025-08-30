resource "aws_vpc" "main" {
cidr_block = var.vpc_cidr
enable_dns_support = true
enable_dns_hostnames = true
tags = { Name = "${var.app_name}-vpc" }
}


resource "aws_internet_gateway" "igw" {
vpc_id = aws_vpc.main.id
tags = { Name = "${var.app_name}-igw" }
}


resource "aws_subnet" "public" {
  for_each                = toset(["0", "1"])
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[tonumber(each.value)]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[tonumber(each.value)]
  tags = {
    Name                     = "${var.app_name}-public-${each.value}"
    "kubernetes.io/role/elb" = 1
  }
}


data "aws_availability_zones" "available" {}


resource "aws_route_table" "public" {
vpc_id = aws_vpc.main.id
tags = { Name = "${var.app_name}-public-rt" }
}


resource "aws_route" "public_inet" {
route_table_id = aws_route_table.public.id
destination_cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.igw.id
}


resource "aws_route_table_association" "public_assoc" {
for_each = aws_subnet.public
subnet_id = each.value.id
route_table_id = aws_route_table.public.id
}