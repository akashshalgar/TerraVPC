provider "aws" {
  region     = "us-east-2"
  access_key = "my-access-key"
  secret_key = "my-secret-key"
}

resource "aws_vpc" "my_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "my_vpc"
  }
}

resource "aws_subnet" "my_sub_public" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "my_sub_public"
  }
}

resource "aws_subnet" "my_sub_private" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "my_sub_private"
  }
}

resource "aws_security_group" "my_secu" {
  name        = "my_secu"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.my_vpc.id

  tags = {
    Name = "my_secu"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.my_secu.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_vpc.my_vpc.cidr_block
  cidr_ipv4         = aws_route_table.my_route_table_private
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my_igw"
  }
}


resource "aws_route_table" "my_route_table_public" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "my_route_table_public"
  }
}

resource "aws_route_table_association" "my_public_asso" {
  subnet_id      = aws_subnet.my_sub_public.id
  route_table_id = aws_route_table.my_route_table_public.id
}

resource "aws_instance" "web" {
  ami           = "ami-033fabdd332044f06"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.my_sub_public.id
  vpc_security_group_ids = [aws_security_group.my_secu.id]
  key_name      = "my_key_name"

  tags = {
    Name = "web"
  }
}
resource "aws_instance" "db" {
  ami           = "ami-033fabdd332044f06"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.my_sub_private.id
  vpc_security_group_ids = [aws_security_group.my_secu.id]
  key_name      = "my_key_name"

  tags = {
    Name = "db"
  }
}

resource "aws_key_pair" "vipul" {
  key_name   = "my_key_name"
  public_key = "my-public-key"
}

resource "aws_eip" "my_eip" {
  instance = aws_instance.web.id
  domain   = "vpc"
}

resource "aws_eip" "my_nat_gw" {
  domain   = "vpc"
}

resource "aws_nat_gateway" "my_nat_gw" {
  allocation_id = aws_eip.my_nat_gw.id
  subnet_id     = aws_subnet.my_sub_public.id

  tags = {
    Name = "my_nat_gw"
  }
}

resource "aws_route_table" "my_route_table_private" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.my_nat_gw.id
  }

  tags = {
    Name = "my_route_table_private"
  }
}

resource "aws_route_table_association" "my_private_asso" {
  subnet_id      = aws_subnet.my_sub_private.id
  route_table_id = aws_route_table.my_route_table_private.id
}