resource "aws_ecr_repository" "api" {
  name                 = "zama-api"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  force_delete = true
}

resource "aws_ecr_repository" "nginx" {
  name                 = "zama-nginx"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  force_delete = true
}

resource "aws_ssm_parameter" "api_key" {
  name        = var.api_key_ssm_name
  description = "API key for Nginx to authenticate clients"
  type        = "String"
  value       = var.api_key_value
  overwrite   = true
}
