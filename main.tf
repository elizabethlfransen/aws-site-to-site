terraform {
  backend "s3" {
    
    key    = "state"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_vpc" "vpc" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    "Name" = "Liz Vpc"
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "Liz Gateway"
  }
}

resource "aws_subnet" "subnet" {
  cidr_block        = aws_vpc.vpc.cidr_block
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "us-east-1a"
}


resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
  tags = {
    "Name" = "Liz Route Table"
  }
}

resource "aws_route_table_association" "route-table-assoc" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.route-table.id
}


resource "aws_instance" "ssh" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet.id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  key_name               = aws_key_pair.ssh_key.key_name
  tags = {
    Name = "SSH"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Allow SSH"
  }
}


resource "aws_eip" "ip" {
  depends_on = [
    aws_internet_gateway.gateway
  ]
  instance = aws_instance.ssh.id
  vpc      = true
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "ssh"
  public_key = file("ssh.pub")
}
