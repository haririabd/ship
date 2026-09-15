variable "aws_account_id" {
  default = "739951718815"
}

variable "aws_region" {
  default = "ap-southeast-1"
}

variable "ecr_repository_name" {
  default = "devops-bootcamp/final-project-haririabd"
}

variable "github_repo" {
  description = "owner/repo that's allowed to assume this role"
  default     = "haririabd/ship"
}
