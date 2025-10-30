variable "region" {
  type        = string
  description = "AWS region"
  default     = "eu-west-1"
}

variable "name_prefix" {
  type        = string
  default     = "zama-challenge"
  description = "Name prefix for resources"
}

variable "desired_count" {
  type        = number
  default     = 2
  description = "ECS desired task count"
}

variable "image_tag" {
  type        = string
  description = "Docker image tag used for both images"
  default     = "v0.1.0"
}

variable "api_key_ssm_name" {
  type        = string
  default     = "/zama/api/api_key"
  description = "SSM parameter name storing the API key"
}

variable "api_key_value" {
  type        = string
  description = "Value for the API key (do NOT commit a real one; set via tfvars)"
  default     = ""
  sensitive   = true
}
