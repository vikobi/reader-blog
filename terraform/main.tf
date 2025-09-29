provider "aws" {
    region = "us-east-1"
    # AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are read from environment variables
}

# ================================================================================
# VPC and Subnets

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
        Name = "${var.web-app}-vpc"
    }
}


# Declare the data source
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnets[count.index]
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[count.index]
    tags = {
            Name = "${var.web-app}-public-subnet-${count.index + 1}" 
        }
}

resource "aws_subnet" "private" {
  count      = length(var.private_subnets)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index] 
    tags = {
            Name = "${var.web-app}-private-subnet-${count.index + 1}"
        }
}

# ================================================================================
# Internet Gateway and Route Table for Public Subnets and Private subnets

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.web-app}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
    tags = {
        Name = "${var.web-app}-public-rt"
    }
}
resource "aws_route_table_association" "pub-rtb-aws_route_table_association" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
  
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.web-app}-nat-eip"
  }
}
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.web-app}-nat-gateway"
  }

  depends_on = [aws_internet_gateway.gw]
  
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
    }  
    tags = {
        Name = "${var.web-app}-private-rt"
    } 
}
resource "aws_route_table_association" "priv-rtb-aws_route_table_association" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ================================================================================
# Security Groups
resource "aws_security_group" "alb_sg" {
  name        = "${var.web-app}-alb-sg"
  description = "Allow HTTP and HTTPS traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "${var.web-app}-alb-sg"
    } 
}
resource "aws_security_group" "ec2_sg" {
  name        = "${var.web-app}-ec2-sg"
  description = "Allow traffic from ALB to EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    description     = "localhost port 3000"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
   ingress {
    description     = "SSH from admin"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = [var.my_ip]  
  }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "${var.web-app}-ec2-sg"
    }   
}  
resource "aws_security_group" "rds_sg" {
  name        = "${var.web-app}-rds-sg"
  description = "Allow traffic from EC2 to RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  ingress {
    description     = "PostgreSQL from admin"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
    tags = {
        Name = "${var.web-app}-rds-sg"
    }  
}

# ================================================================================
# Application Load Balancer + Target Group + Listener
resource "aws_lb" "alb" {
  name               = "${var.web-app}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.web-app}-alb"
  }
}

# Backend target group on port 4000
resource "aws_lb_target_group" "tg_backend" {
  name     = "${var.web-app}-backend"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.web-app}-backend-tg"
  }
}

# Rule: /api/* goes to backend target group
resource "aws_lb_listener_rule" "api_rule" {
  listener_arn = aws_lb_listener.listener_frontend.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# Frontend target group on port 3000
resource "aws_lb_target_group" "tg_frontend" {
  name     = "${var.web-app}-frontend"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }
    tags = {
        Name = "${var.web-app}-frontend-tg"
    }
}
resource "aws_lb_listener" "listener_frontend" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_frontend.arn
  }
}

output "application_load_balancer_dns" {
  value = aws_lb.alb.dns_name
}

# ================================================================================
# IAM Role and Instance Profile for EC2
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

output "ami_id" {
  value = data.aws_ami.amazon_linux_2023.id
}   

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "ec2_role" {
  name               = "${var.web-app}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.web-app}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Launch Template for EC2 Instances

resource "aws_key_pair" "dev-key" {
  key_name   = var.key_name
  public_key = file(var.public_key_location)  # Ensure you have the public key file
  
}
resource "aws_launch_template" "app" {
  name_prefix   = "${var.web-app}-lt"
  image_id      = data.aws_ami.amazon_linux_2023.id     #  uses lookup, not var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.dev-key.key_name

  network_interfaces {
  associate_public_ip_address = true
  security_groups             = [aws_security_group.ec2_sg.id]
}


  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(<<-EOF
                #!/bin/bash
                dnf update -y || true
                dnf install -y nodejs npm git || true
                useradd -m deploy || true
                mkdir -p /home/deploy/.ssh
                chmod 400 /home/deploy/.ssh
                chown -R deploy:deploy /home/deploy/.ssh
                systemctl enable sshd
                systemctl start sshd
                
                EOF
            )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.web-app}-ec2-instance"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  desired_capacity     = var.asg_desired_capacity
  max_size             = var.asg_max_size
  min_size             = var.asg_min_size
  vpc_zone_identifier  = aws_subnet.public[*].id  # Use public subnets for ALB access
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.tg_3000.arn]

  tag {
    key                 = "Name"
    value               = "${var.web-app}-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ================================================================================
# RDS PostgresSQL
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.web-app}-rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.web-app}-rds-subnet-group"
  }
}

resource "aws_db_instance" "rds" {
  identifier              = "${var.web-app}-db-instance"
  allocated_storage       = var.rds_allocated_storage
  engine                  = var.rds_engine
  engine_version          = var.rds_engine_version
  instance_class          = var.rds_instance_class
  username                = var.rds_username
  password                = var.rds_password
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = true

  tags = {
    Name = "${var.web-app}-rds-instance"
  }
}
output "rds_endpoint" {
  value = aws_db_instance.rds.endpoint
}

output "rds_port" {
  value = aws_db_instance.rds.port
} 