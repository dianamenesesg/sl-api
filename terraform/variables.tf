variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name, used as prefix for all resource names"
  type        = string
  default     = "sl-api"
}

variable "nebius_api_key" {
  description = "Nebius AI API key — stored in Secrets Manager, never in state as plaintext"
  type        = string
  sensitive   = true
}

variable "cpu" {
  description = "vCPU units for the App Runner container (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "512"
}

variable "memory" {
  description = "Memory in MB for the App Runner container (512, 1024, 2048, 3072, 4096, 6144, 8192, 10240, 12288)"
  type        = string
  default     = "1024"
}
