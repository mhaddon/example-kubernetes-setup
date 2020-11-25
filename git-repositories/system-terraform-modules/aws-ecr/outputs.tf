output "repository_names" {
  value = aws_ecr_repository.main.*.name
}

output "repository_ids" {
  value = aws_ecr_repository.main.*.id
}