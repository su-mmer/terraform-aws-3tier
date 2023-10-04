terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Name = "terraform-frog"
    }
  }
}

# vpc
resource "aws_vpc" "main" {
  cidr_block = "10.0.180.0/24"
}

# public subnet
resource "aws_subnet" "public-2a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.180.0/28"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "public-2a-nat"
  }
}

resource "aws_subnet" "public-2c" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.180.64/28"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "public-2c-bastion"
  }
}

# private subnet
resource "aws_subnet" "private-1a-web" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.180.16/28"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "private-1a-web"
  }
}

resource "aws_subnet" "private-1a-was" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.180.32/28"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "private-1a-was"
  }
}

resource "aws_subnet" "private-1a-db" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.180.48/28"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "private-1a-db"
  }
}

resource "aws_subnet" "private-1c-web" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.180.80/28"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "private-1c-web"
  }
}

resource "aws_subnet" "private-1c-was" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.180.96/28"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "private-1c-was"
  }
}

# routing table 생성 - public subnet, igw 연결
resource "aws_route_table" "main_route" {
  vpc_id     = aws_vpc.main.id
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
    Name = "terraform-frog-igw"
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
  subnet_id = aws_subnet.public-2a.id
  tags = {
    Name = "frog-nat"
  }
}
