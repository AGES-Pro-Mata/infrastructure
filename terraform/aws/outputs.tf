# Outputs for AWS Production Environment

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.prod.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.prod.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.prod.arn
}

output "security_group_id" {
  description = "ID of the ECS security group"
  value       = aws_security_group.ecs.id
}
