output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "public_subnet_ids" {
  value = [
    aws_subnet.public-a.id,
    aws_subnet.public-c.id
  ]
}

output "public_subnet_cidr_blocks" {
  value = [
    aws_subnet.public-a.cidr_block,
    aws_subnet.public-c.cidr_block
  ]
}

output "private_subnet_ids" {
  value = [
    aws_subnet.private-a.id,
    aws_subnet.private-c.id
  ]
}

output "private_subnet_cidr_blocks" {
  value = [
    aws_subnet.private-a.cidr_block,
    aws_subnet.private-c.cidr_block
  ]
}

# 初期構築時は bastion = nat instance
# SSH接続自体はSSM SessionManagerを経由し、22番ポートの開放は不要
output "bastion_security_group_id" {
  value = aws_security_group.nat_instance.id
}