provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "web-vpc" {
  cidr_block           = "20.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    "Name"        = "apache-web-vpc"
    "environment" = "dev"
    "terraform"   = "true"
  }
}

resource "aws_subnet" "web-subnet-1" {
  cidr_block        = "20.0.1.0/24"
  vpc_id            = aws_vpc.web-vpc.id
  availability_zone = "ap-south-1a"
  tags = {
    "Name"        = "apache-web-vpc-subnet1"
    "environment" = "dev"
    "terraform"   = "true"
  }
}

resource "aws_subnet" "web-subnet-2" {
  vpc_id            = aws_vpc.web-vpc.id
  cidr_block        = "20.0.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    "Name"        = "apache-web-vpc-subnet2"
    "environment" = "dev"
    "terraform"   = "true"
  }
}

resource "aws_internet_gateway" "apache-web-ig" {
  vpc_id = aws_vpc.web-vpc.id
  tags = {
    "Name"        = "apache-web-ig"
    "environment" = "dev"
    "terraform"   = "true"
  }
}

resource "aws_route_table" "apche-web-route-table" {
  vpc_id = aws_vpc.web-vpc.id
  route = [{
    cidr_block                 = "0.0.0.0/0"
    gateway_id                 = aws_internet_gateway.apache-web-ig.id
    carrier_gateway_id         = ""
    destination_prefix_list_id = ""
    egress_only_gateway_id     = ""
    instance_id                = ""
    ipv6_cidr_block            = ""
    local_gateway_id           = ""
    nat_gateway_id             = ""
    network_interface_id       = ""
    transit_gateway_id         = ""
    vpc_endpoint_id            = ""
    vpc_peering_connection_id  = ""
  }]

  tags = {
    "Name"        = "Apache VPC Subnets Route Table"
    "environment" = "dev"
    "terraform"   = "true"
  }
}

resource "aws_route_table_association" "apache-web-vpc-rt-subnet-1" {
  subnet_id      = aws_subnet.web-subnet-1.id
  route_table_id = aws_route_table.apche-web-route-table.id
}

resource "aws_route_table_association" "apache-web-vpc-rt-subnet-2" {
  subnet_id      = aws_subnet.web-subnet-2.id
  route_table_id = aws_route_table.apche-web-route-table.id
}

resource "aws_security_group" "apache-web-sg" {
  name        = "allow_http"
  description = "Allow HTTP Inbound Connections"
  vpc_id      = aws_vpc.web-vpc.id

  ingress = [
    {
      description      = "HTTP"
      cidr_blocks      = ["0.0.0.0/0"]
      from_port        = 80
      protocol         = "tcp"
      to_port          = 80
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false

    },

    {
      description      = "SSH"
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      cidr_blocks      = ["0.0.0.0/0"]
      from_port        = 22
      protocol         = "tcp"
      to_port          = 22
      security_groups  = []
      self             = false
    }
  ]


  egress = [
    {
      description      = "Allow Outbound Traffic"
      cidr_blocks      = ["0.0.0.0/0"]
      from_port        = 0
      protocol         = "-1"
      to_port          = 0
      security_groups  = []
      prefix_list_ids  = []
      ipv6_cidr_blocks = []
      self             = false
    }
  ]

  tags = {
    "Name"        = "Allow HTTP for Inbound"
    "environment" = "dev"
    "terraform"   = "true"
  }
}

data "aws_ami" "latest_ami_ap" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
resource "aws_launch_configuration" "apache-web" {
  image_id      = data.aws_ami.latest_ami_ap.id
  instance_type = "t2.micro"
  key_name      = "EC2-AMI-Key"

  security_groups             = [aws_security_group.apache-web-sg.id]
  associate_public_ip_address = true

  user_data = file("setup-LAMP.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "apache-elb" {
  name                      = "apache-elb"
  security_groups           = [aws_security_group.apache-web-sg.id]
  subnets                   = [aws_subnet.web-subnet-1.id, aws_subnet.web-subnet-2.id]
  cross_zone_load_balancing = true

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    target              = "HTTP:80/phpinfo.php"
  }

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "80"
    instance_protocol = "http"

  }
}

resource "aws_autoscaling_group" "apache-asg" {
  name = "${aws_launch_configuration.apache-web.name}-asg"

  min_size         = 1
  desired_capacity = 2
  max_size         = 4

  health_check_type    = "ELB"
  load_balancers       = [aws_elb.apache-elb.id]
  launch_configuration = aws_launch_configuration.apache-web.name

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  vpc_zone_identifier = [aws_subnet.web-subnet-1.id, aws_subnet.web-subnet-2.id]

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "apache-web"
    propagate_at_launch = true
  }
}