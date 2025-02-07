output "kms_key_arn" {
  value = aws_kms_key.s3_kms.arn
}

output "vpc_id" {
  value = aws_vpc.my_vpc_exam.id
}

output "public_subnet_id" {
  value = aws_subnet.public_subnet.id
}

output "private_subnet_id" {
  value = aws_subnet.private_subnet.id
}
output "route_table_id" {
  value = aws_route_table.public_route_table.id
}