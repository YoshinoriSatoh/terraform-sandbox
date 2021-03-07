data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc.cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = merge(
    local.common_tags,
    {
      Name = local.infra_fullname
    }
  )
}

resource "aws_subnet" "public-a" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "${data.aws_region.current.name}a"
  cidr_block        = var.subnets.public.a.cidr_block
  tags = merge(
    local.common_tags,
    {
      Name = "${local.infra_fullname}-public-a"
    }
  )
}

resource "aws_subnet" "public-c" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "${data.aws_region.current.name}c"
  cidr_block        = var.subnets.public.c.cidr_block
  tags = merge(
    local.common_tags,
    {
      Name = "${local.infra_fullname}-public-c"
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.infra_fullname}-public"
    }
  )
}

resource "aws_route_table_association" "public-a" {
  subnet_id      = aws_subnet.public-a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public-c" {
  subnet_id      = aws_subnet.public-c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private-a" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "${data.aws_region.current.name}a"
  cidr_block        = var.subnets.private.a.cidr_block
  tags = merge(
    local.common_tags,
    {
      Name = "${local.infra_fullname}-private-a"
    }
  )
}

resource "aws_subnet" "private-c" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "${data.aws_region.current.name}c"
  cidr_block        = var.subnets.private.c.cidr_block
  tags = merge(
    local.common_tags,
    {
      Name = "${local.infra_fullname}-private-c"
    }
  )
}

resource "aws_route_table" "private-a" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    instance_id = aws_instance.nat-a.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.infra_fullname}-private-a"
    }
  )
}

resource "aws_route_table_association" "private-a" {
  subnet_id      = aws_subnet.private-a.id
  route_table_id = aws_route_table.private-a.id
}

resource "aws_route_table_association" "private-c" {
  subnet_id      = aws_subnet.private-c.id
  route_table_id = aws_route_table.private-a.id 
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(
    local.common_tags,
    {
      Name = local.infra_fullname
    }
  )
}

resource "aws_instance" "nat-a" {
  ami           = var.nat_instance.ami
  instance_type = var.nat_instance.instance_type
  subnet_id     = aws_subnet.public-a.id
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.nat.id
  vpc_security_group_ids = [aws_security_group.nat_instance.id]
  key_name               = aws_key_pair.nat_instance.key_name
  source_dest_check = false 

  tags = merge(
    local.common_tags,
    {
      Name = "${local.infra_fullname}-nat-instance-a"
    }
  )
}

resource "aws_eip" "nat-instance-a" {
  vpc = true
  instance = aws_instance.nat-a.id
  depends_on = [aws_internet_gateway.gw]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.infra_fullname}-nat-instance-a"
    }
  )
}

resource "aws_key_pair" "nat_instance" {
  key_name   = "nat_instance-${var.infra.env}"
  public_key = file("./key_pairs/nat_instance_${var.infra.env}.pub") 
}

resource "aws_iam_instance_profile" "nat" {
  name = "nat-${var.infra.env}"
  role = aws_iam_role.nat.name
}

resource "aws_iam_role" "nat" {
  name = "nat_instance_role-${var.infra.env}"
  path = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF

  tags = merge(
    local.common_tags,
    {
      Name = "${local.infra_fullname}-nat-instance"
    }
  )
}

resource "aws_iam_role_policy_attachment" "nat_instance_attach_role" {
  role       = aws_iam_role.nat.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_security_group" "nat_instance" {
  name        = "nat_instance"
  description = "nat_instance security group"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "from private subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [
      aws_subnet.private-a.cidr_block,
      aws_subnet.private-c.cidr_block
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.infra_fullname}-nat-instance"
    }
  )
}
