provider "aws" {
  secret_key = ""
  access_key = ""
  region = "us-east-1"
}

resource "aws_vpc" "docker_test" {
  cidr_block = "10.77.0.0/16"
  instance_tenancy = "default"

  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "Docker-DNS-Test"
  }
}

resource "aws_subnet" "docker_test" {
  vpc_id = aws_vpc.docker_test.id
  cidr_block = "10.77.1.0/24"

  map_public_ip_on_launch = true

  tags = {
    Name = "Docker-DNS-Test-Public"
  }
}

resource "aws_internet_gateway" "docker_test" {
  vpc_id = aws_vpc.docker_test.id

  tags = {
    Name = "Docker-DNS-Test-IGW"
  }
}

resource "aws_route_table" "docker_test" {
  vpc_id = aws_vpc.docker_test.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.docker_test.id
  }

  tags = {
    Name = "Docker-DNS-Test-Public-Routes"
  }
}

resource "aws_route_table_association" "docker_test" {
  route_table_id = aws_route_table.docker_test.id
  subnet_id = aws_subnet.docker_test.id
}

resource "aws_main_route_table_association" "docker_test" {
  vpc_id = aws_vpc.docker_test.id
  route_table_id = aws_route_table.docker_test.id
}


resource "aws_vpc_dhcp_options" "docker_test" {
  domain_name = "docker.test"
  domain_name_servers = [
    "1.1.1.1",
  ]
  ntp_servers = [
    "169.254.169.123",
  ]

  tags = {
    Name = "Docker-DNS-Test-DHCP"
  }
}

resource "aws_vpc_dhcp_options" "docker_test_aws" {
  domain_name = "docker.test"
  domain_name_servers = [
    "AmazonProvidedDNS",
  ]
  ntp_servers = [
    "169.254.169.123",
  ]

  tags = {
    Name = "Docker-DNS-Test-AWS-DHCP"
  }
}

resource "aws_vpc_dhcp_options_association" "docker_test" {
  dhcp_options_id = aws_vpc_dhcp_options.docker_test_aws.id
  vpc_id = aws_vpc.docker_test.id
}

resource "aws_security_group" "docker_test" {
  name = "Docker-DNS-Test-SG"
  vpc_id = aws_vpc.docker_test.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  tags = {
    Name = "Docker-DNS-Test-SG"
  }
}

resource "aws_key_pair" "docker_test" {
  public_key = file("~/.ssh/id_rsa.pub")
  key_name_prefix = "Docker-DNS-Test-SSH-Key"
}

resource "aws_instance" "docker_test" {

  # Ubuntu Server 18.04 LTS (HVM), SSD Volume Type
  ami = "ami-07ebfd5b3428b6f4d"
  instance_type = "t3a.nano"

  vpc_security_group_ids = [
    aws_security_group.docker_test.id,
  ]
  subnet_id = aws_subnet.docker_test.id
  key_name = aws_key_pair.docker_test.key_name

  ebs_optimized = true
  disable_api_termination = false
  source_dest_check = true

  user_data = file("${path.module}/install-docker.txt")

  associate_public_ip_address = true

  hibernation = false
  monitoring = false

  credit_specification {
    cpu_credits = "standard"
  }

  tags = {
    Name = "Docker-DNS-Test-Instance"
  }

  depends_on = [
    aws_internet_gateway.docker_test,
    aws_security_group.docker_test,
  ]
}

resource "aws_route53_zone" "docker_test" {
  name = "docker.test"

  vpc {
    vpc_id = aws_vpc.docker_test.id
  }
}

resource "aws_route53_record" "docker_test_public" {
  zone_id = aws_route53_zone.docker_test.id
  name = "public.instance.docker.test"
  type = "A"
  ttl = "300"
  records = [
    aws_instance.docker_test.public_ip,
  ]
}

resource "aws_route53_record" "docker_test_private" {
  zone_id = aws_route53_zone.docker_test.id
  name = "private.instance.docker.test"
  type = "A"
  ttl = "300"
  records = [
    aws_instance.docker_test.private_ip,
  ]
}
