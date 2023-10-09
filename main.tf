terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Name = "${var.name}"
    }
  }
}

# locals {
#   public_subnet_list = [
#     {
#       name = "public-a"
#       subnet_cidr = cidrsubnet(var.cidr_block, 4, 1)
#       availability_zone = 
#     },
#     {
#       name="public-c"
#       subnet_cidr = cidrsubnet(var.cidr_block. 4, 2)
#     }
#   ]
# }

# vpc
resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
}

# public subnet
# resource "aws_subnet" "public-2a" {
#   count = 2
#   vpc_id = aws_vpc.main.id
#   cidr_block = var.public_subnet_list[count.index].subnet_cidr
#   availability_zone = 
# }
resource "aws_subnet" "public-2a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.180.0/28"
  availability_zone = "${var.region}a"
  tags = {
    Name = "public-2a-nat"
  }
}

resource "aws_subnet" "public-2c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.180.64/28"
  availability_zone = "${var.region}c"
  tags = {
    Name = "public-2c-bastion"
  }
}

# private subnet
resource "aws_subnet" "private-1a-web" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.180.16/28"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "private-1a-web"
  }
}

resource "aws_subnet" "private-1a-was" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.180.32/28"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "private-1a-was"
  }
}

resource "aws_subnet" "private-1a-db" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.180.48/28"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "private-1a-db"
  }
}

resource "aws_subnet" "private-1c-web" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.180.80/28"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "private-1c-web"
  }
}

resource "aws_subnet" "private-1c-was" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.180.96/28"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "private-1c-was"
  }
}

# routing table 생성 - public subnet, igw 연결
resource "aws_route_table" "main_route" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
  tags = {
    Name = "public_rt"
  }
}
# default routing table- private subent, nat 연결
resource "aws_default_route_table" "name" {
  default_route_table_id = aws_vpc.main.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.main_nat.id
  }
  tags = {
    Name = "default_rt"
  }
}
# routing table에 public subnet 추가
resource "aws_route_table_association" "routing_a" {
  subnet_id      = aws_subnet.public-2a.id
  route_table_id = aws_route_table.main_route.id
}

resource "aws_route_table_association" "routing_c" {
  subnet_id      = aws_subnet.public-2c.id
  route_table_id = aws_route_table.main_route.id
}

# igw
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name}-igw"
  }
}

# nat
resource "aws_eip" "nat-eip" {
  tags = {
    Name = "nat-eip"
  }
}
resource "aws_nat_gateway" "main_nat" {
  allocation_id = aws_eip.nat-eip.id
  subnet_id     = aws_subnet.public-2a.id
  tags = {
    Name = "${var.name}-nat"
  }
}

# 보안 그룹
# resource "aws_security_group" "sg_bastion" {
#   vpc_id = aws_vpc.main.id
#   description = "allow 22 port for bastion"
#   ingress {
#     from_port = 22
#     to_port = 22
#     protocol = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   egress {
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = {
#     Name = "${var.name}-bastion"
#   }
# }

resource "aws_security_group" "bastion" {
  vpc_id = aws_vpc.main.id
  name        = "bastion security group"
  description = "bastion security group"

  tags = {
    Name = "${var.name}-bastion"
  }
}

resource "aws_security_group" "web" {
  vpc_id = aws_vpc.main.id
  name        = "WEB security group"
  description = "WEB security group"

  tags = {
    Name = "${var.name}-WEB"
  }
}

resource "aws_security_group_rule" "sg_bastion_ingress" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "TCP"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id        = aws_security_group.bastion.id
  # source_security_group_id = "${aws_security_group.frontend_load_balancer.id}"
}

resource "aws_security_group_rule" "sg_bastion_egress" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id        = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "sg_web_ingress" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "TCP"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = aws_security_group.web.id
}

resource "aws_security_group_rule" "sg_web_egress" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id        = aws_security_group.web.id
}

# Bastion-instance
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20230918"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "main_key" {
  key_name = "${var.name}-key"
  public_key = file("./ssh-key.pub")
}

resource "aws_eip" "bastion_eip" {
  instance = aws_instance.bastion.id
  tags = {
    Name = "${var.name}-bastion"
  }
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.public-2c.id
  vpc_security_group_ids = [ aws_security_group.bastion.id ]
  key_name = "${var.name}-key"

  # connection {
  #   type     = "ssh"
  #   user     = "root"
  #   private_key = "./ssh-key.pem"
  #   host     = aws_instance.bastion.id
  # }

  # provisioner "file" {
  #   source = "ssh-key.pem"
  #   destination = "${var.name}.pem"
  # }

  tags = {
    Name = "${var.name}-bastion"
  }
}
resource "terraform_data" "ssh-key_gen" {
  connection {
    type     = "ssh"
    user     = "root"
    private_key = "./ssh-key.pem"
    host     = aws_instance.bastion.id
  }
  provisioner "file" {
    source = "ssh-key.pem"
    destination = "${var.name}.pem"
  }
}
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.private-1a-web.id
  vpc_security_group_ids = [ aws_security_group.web.id ]
  key_name = "${var.name}-key"

  tags = {
    Name = "${var.name}-web01"
  }
}