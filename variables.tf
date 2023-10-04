# vpc variable
variable "name" {
  type        = string
  default     = "terraform-frog"
  description = "All resources name incloud this value"
}

variable "region" {
  type        = string
  default     = "ap-northeast-2"
  description = "리소스를 생성할 리전"
}

variable "cidr_block" {
  type    = string
  default = "10.0.180.0/24"
}