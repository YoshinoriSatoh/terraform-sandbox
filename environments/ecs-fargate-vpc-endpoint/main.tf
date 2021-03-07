locals {
  profile = var.profile
}

provider "aws" {
  region = "ap-northeast-1"
  profile = local.profile
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

## VPC
resource "aws_vpc" "main" {
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

resource "aws_subnet" "private-a" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "${data.aws_region.current.name}a"
  cidr_block        = var.subnets.private.a.cidr_block
  tags = merge(
    local.common_tags,
    {
      Name = "${local.infra_fullname}-private-a"
    }
  )
}

resource "aws_route_table" "private-a" {
  vpc_id = aws_vpc.main.id

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

resource "aws_security_group" "vpc-endpoint" {
  name        = "vpc-endpoint"
  description = "vpc-endpoint security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "from private subnet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [
      aws_subnet.private-a.cidr_block
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
      Name = "${local.infra_fullname}-vpc-endpoint"
    }
  )
}

## VPC Endpoints
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [ aws_route_table.private-a.id ]
}

resource "aws_vpc_endpoint" "ecr-dkr" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids = [ aws_subnet.private-a.id ]
  security_group_ids = [ aws_security_group.vpc-endpoint.id ]
}

resource "aws_vpc_endpoint" "ecr-api" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids = [ aws_subnet.private-a.id ]
  security_group_ids = [ aws_security_group.vpc-endpoint.id ]
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids = [ aws_subnet.private-a.id ]
  security_group_ids = [ aws_security_group.vpc-endpoint.id ]
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids = [ aws_subnet.private-a.id ]
  security_group_ids = [ aws_security_group.vpc-endpoint.id ]
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids = [ aws_subnet.private-a.id ]
  security_group_ids = [ aws_security_group.vpc-endpoint.id ]
}

## ECS
resource "aws_ecs_cluster" "cluster" {
  name = local.infra_fullname
  capacity_providers = ["FARGATE"]
}

resource "aws_ecs_task_definition" "default" {
  family                = local.infra_fullname
  container_definitions = file("container_definitions.json")
  task_role_arn = aws_iam_role.task-role.arn
  execution_role_arn = aws_iam_role.task-execution-role.arn
  cpu = 256
  memory = 512
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  depends_on = [
    aws_vpc_endpoint.s3,
    aws_vpc_endpoint.ecr-dkr,
    aws_vpc_endpoint.secretsmanager,
    aws_vpc_endpoint.ssm,
    aws_vpc_endpoint.logs,
    aws_ssm_parameter.example,
    aws_secretsmanager_secret_version.example,
  ]
}

### ECS Task Role
resource "aws_iam_role" "task-role" {
  name = "${local.infra_fullname}-task-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF

  tags = merge(
    local.common_tags,
    {
      Name = "${local.infra_fullname}-task-role"
    }
  )
}

### ECS Task Ececution Role
resource "aws_iam_role" "task-execution-role" {
  name = "${local.infra_fullname}-task-execution-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF

  tags = merge(
    local.common_tags,
    {
      Name = "${local.infra_fullname}-task-execution-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "AmazonECSTaskExecutionRolePolicy" {
  role       = aws_iam_role.task-execution-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "task-execution-policy" {
  name        = "${local.infra_fullname}-execution-policy"
  description = "${local.infra_fullname} execution policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ssm:GetParameters",
        "secretsmanager:GetSecretValue"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*",
        "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:sourceVpce": [ 
            "${aws_vpc_endpoint.s3.id}",
            "${aws_vpc_endpoint.ecr-dkr.id}",
            "${aws_vpc_endpoint.secretsmanager.id}",
            "${aws_vpc_endpoint.ssm.id}",
            "${aws_vpc_endpoint.logs.id}"
          ],
          "aws:sourceVpc": "${aws_vpc.main.id}"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "task-execution-policy-attach" {
  role       = aws_iam_role.task-execution-role.name
  policy_arn = aws_iam_policy.task-execution-policy.arn
}

resource "aws_cloudwatch_log_group" "default" {	
  name = "/aws/ecs/${local.infra_fullname}"

  tags = merge(	
    local.common_tags,	
    {}	
  )	
}

## Parameter Store
resource "aws_ssm_parameter" "example" {
  name  = "parameter_store_secret"
  type  = "SecureString"
  value = "parameter_store_secret_value"
}

## Secrets Manager
resource "aws_secretsmanager_secret" "example" {
  name = "secrets_manager_secret"
}
resource "aws_secretsmanager_secret_version" "example" {
  secret_id     = aws_secretsmanager_secret.example.id
  secret_string = "secrets_manager_secret_value"
}
resource "aws_secretsmanager_secret_policy" "example" {
  secret_arn = aws_secretsmanager_secret.example.arn

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnableAllPermissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "539459320497"
      },
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "*"
    }
  ]
}
POLICY
}