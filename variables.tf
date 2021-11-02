variable "vpc_cidr" {
    type = string
    description = "CIDR Block for the VPC"
    default = "20.0.0.0/16"
}

variable "availability_zones" {
    type = list(string)
    description = "List of Availability Zones for Subnets"
    default = ["ap-south-1a", "ap-south-1b"]
}

variable "subnets" {
    type = list(string)
    description = "List of Public Subnets"
    default = ["20.0.1.0/24", "20.0.2.0/24"]
}