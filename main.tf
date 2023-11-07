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

# vpc
resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
}

# public subnet
resource "aws_subnet" "public-2a-nat" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.180.0/28"
  availability_zone = "${var.region}a"
  tags = {
    Name = "public-2a-nat"
  }
}

resource "aws_subnet" "public-2c-bastion" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.180.96/28"
  availability_zone = "${var.region}c"
  tags = {
    Name = "public-2c-bastion"
  }
}

locals {
  private_web_subnet_list = [  // private subnet을 만들 때 사용할 배열
    {
      name              = "private-1a-web"  // private subnet을 만들 때 사용할 이름
      subnet_cidr       = cidrsubnet(aws_vpc.main.cidr_block, 4, 1)  // 10.0.180.16/28
      availability_zone = "ap-northeast-2a"
    },
    {
      name              = "private-1c-web"
      subnet_cidr       = cidrsubnet(aws_vpc.main.cidr_block, 4, 2)  // 10.0.180.32/24
      availability_zone = "ap-northeast-2c"
    },
  ]

  private_was_subnet_list = [
    {
      name              = "private-1a-was"  // private subnet을 만들 때 사용할 이름
      subnet_cidr       = cidrsubnet(aws_vpc.main.cidr_block, 4, 3)  // 10.0.180.48/28
      availability_zone = "ap-northeast-2a"
    },
    {
      name              = "private-1c-was"
      subnet_cidr       = cidrsubnet(aws_vpc.main.cidr_block, 4, 4)  // 10.0.180.64/24
      availability_zone = "ap-northeast-2c"
    },
  ]

  private_db_subnet_list = [
    {
      name              = "private-1a-db"  // private subnet을 만들 때 사용할 이름
      subnet_cidr       = cidrsubnet(aws_vpc.main.cidr_block, 4, 5)  // 10.0.180.80/28
      availability_zone = "ap-northeast-2a"
    },
  ]

}

resource "aws_subnet" "private-web" {  // subnet 생성
  count                   = 2  // 갯수
  vpc_id                  = aws_vpc.main.id  // 생성한 vpc id
  cidr_block              = local.private_web_subnet_list[count.index].subnet_cidr  // 전달받은 cidr로 subnet 생성
  availability_zone       = local.private_web_subnet_list[count.index].availability_zone  // 전달받은 az
  tags = {
    Name = "${local.private_web_subnet_list[count.index].name}"
  }
}

resource "aws_subnet" "private-was" {  // subnet 생성
  count                   = 2  // 갯수
  vpc_id                  = aws_vpc.main.id  // 생성한 vpc id
  cidr_block              = local.private_was_subnet_list[count.index].subnet_cidr  // 전달받은 cidr로 subnet 생성
  availability_zone       = local.private_was_subnet_list[count.index].availability_zone  // 전달받은 az
  tags = {
    Name = "${local.private_was_subnet_list[count.index].name}"
  }
}

resource "aws_subnet" "private-db" {  // subnet 생성
  count                   = 1  // 갯수
  vpc_id                  = aws_vpc.main.id  // 생성한 vpc id
  cidr_block              = local.private_db_subnet_list[count.index].subnet_cidr  // 전달받은 cidr로 subnet 생성
  availability_zone       = local.private_db_subnet_list[count.index].availability_zone  // 전달받은 az
  tags = {
    Name = "${local.private_db_subnet_list[count.index].name}"
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
  subnet_id      = aws_subnet.public-2a-nat.id
  route_table_id = aws_route_table.main_route.id
}

resource "aws_route_table_association" "routing_c" {
  subnet_id      = aws_subnet.public-2c-bastion.id
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
  subnet_id     = aws_subnet.public-2a-nat.id
  tags = {
    Name = "${var.name}-nat"
  }
}

# 보안 그룹
resource "aws_security_group" "web" {
  vpc_id = aws_vpc.main.id
  name        = "web-sg"
  description = "web security group"

  tags = {
    Name = "${var.name}-web"
  }
}

resource "aws_security_group" "was" {
  vpc_id = aws_vpc.main.id
  name        = "was-sg"
  description = "was security group"

  tags = {
    Name = "${var.name}-was"
  }
}

resource "aws_security_group" "db" {
  vpc_id = aws_vpc.main.id
  name        = "db-sg"
  description = "db security group"

  tags = {
    Name = "${var.name}-db"
  }
}

resource "aws_security_group" "alb" {
  vpc_id = aws_vpc.main.id
  name        = "alb-sg"
  description = "alb security group"

  tags = {
    Name = "${var.name}-alb"
  }
}

resource "aws_security_group_rule" "sg_web_ingress" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "TCP"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.web.id
}

resource "aws_security_group_rule" "sg_web_egress_all" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id        = aws_security_group.web.id
}

resource "aws_security_group_rule" "sg_was_ingress" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "TCP"
  source_security_group_id = aws_security_group.web.id
  security_group_id        = aws_security_group.was.id
}

resource "aws_security_group_rule" "sg_was_egress" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "TCP"
  source_security_group_id = aws_security_group.db.id
  security_group_id        = aws_security_group.was.id
}

resource "aws_security_group_rule" "sg_was_egress_443" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "TCP"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id        = aws_security_group.was.id
}

resource "aws_security_group_rule" "sg_db_ingress" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "TCP"
  source_security_group_id = aws_security_group.was.id
  security_group_id        = aws_security_group.db.id
}

resource "aws_security_group_rule" "sg_db_egress" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id        = aws_security_group.db.id
}

resource "aws_security_group_rule" "sg_alb_ingress" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "TCP"
  cidr_blocks = ["0.0.0.0/0"]  # 외부로부터 들어오는 모든 통신
  security_group_id        = aws_security_group.alb.id
}

resource "aws_security_group_rule" "sg_alb_egress" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "TCP"
  source_security_group_id = aws_security_group.web.id  # 통신을 web 보안그룹으로 전달해줌
  security_group_id        = aws_security_group.alb.id
}

# instance
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "image-id"
    values = ["ami-09af799f87c7601fa"]
    # values = ["ami-03a94e768a99fbb77"]  # ubuntu
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  count = 2
  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.private-web[count.index].id
  vpc_security_group_ids = [ aws_security_group.web.id ]
  iam_instance_profile = "hh-terraform-ec2-ssm"

  user_data = <<EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y httpd
    echo $(ec2-metadata -i) | sudo tee /var/www/html/index.html
    sudo systemctl start httpd.service
    sudo systemctl enable httpd.service
  EOF

  tags = {
    Name = "${var.name}-web${count.index}"
  }
}

resource "aws_instance" "was" {
  count = 2
  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.private-was[count.index].id
  vpc_security_group_ids = [ aws_security_group.was.id ]
  iam_instance_profile = "hh-terraform-ec2-ssm"
  user_data = <<-EOF
   
  EOF

  tags = {
    Name = "${var.name}-was${count.index}"
  }
}

# ALB 설정
resource "aws_lb_target_group" "web_target" {
  name = "${var.name}-web-target"
  port = 80
  protocol = "HTTP"
  health_check {
    path = "/index.html"
    protocol = "HTTP"
  }
  vpc_id = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "target_attach1" {
  count = 2
  target_group_arn = aws_lb_target_group.web_target.arn
  target_id = aws_instance.web[count.index].id
}

resource "aws_lb_listener" "web_alb_listener" {
  load_balancer_arn = aws_alb.web_alb.arn
  port = "80"
  protocol = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_target.arn
  }
}

resource "aws_alb" "web_alb" {
  name = "${var.name}-alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [ aws_security_group.alb.id ]
  subnets = [ aws_subnet.public-2a-nat.id, aws_subnet.public-2c-bastion.id ]
}