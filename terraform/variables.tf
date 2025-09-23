variable vpc_cidr {
    description = "CIDR block for the VPC"
}
variable web-app {
  description = "name prefix for web application"
  type        = string
  default     = "reader"
}
variable my_ip {
  description = "Your IP address for SSH access"
  type        = string
}
variable "key_name" {
  description = "The name of the SSH key pair that aws would use to access the EC2 instance"
  type        = string
  
}
variable "public_key_location" {
  description = "The location of the public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"  # Update this path if your public key is located elsewhere
}
variable instance_type {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"  # Free Tier eligible in most regions
}
variable public_subnets {}
variable private_subnets {}
variable rds_instance_class {}
variable rds_engine {}
variable rds_engine_version {}
variable rds_username {}
variable rds_password {}
variable rds_allocated_storage {}
variable alb_name {}
variable alb_internal {}
variable ec2_instance_type {}
variable ec2_ami_id {}
variable asg_min_size {}
variable asg_max_size {}
variable asg_desired_capacity {}
