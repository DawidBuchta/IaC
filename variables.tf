variable "admin_username" {
  type        = string
  description = "Login administratora VM"
}

variable "admin_password" {
  type        = string
  description = "Hasło administratora VM"
  sensitive   = true # ukryje wartość w logach
}