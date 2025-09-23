

vpc_cidr = "10.0.0.0/16"
public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
my_ip = "62.49.159.46/32" # Replace with your actual IP address
key_name = "dev-key-pair" # Replace with your actual key pair name
public_key_location = "~/.ssh/id_rsa.pub"


# RDS Free Tier: db.t3.micro or db.t2.micro (PostgreSQL)
rds_instance_class     = "db.t3.micro"
rds_engine             = "postgres"
rds_engine_version     = "14" # Use a supported Free Tier version
rds_username           = "dbadmin"
rds_password           = "yourpassword"
rds_allocated_storage  = 20 # Free Tier allows up to 20GB

alb_name            = "my-alb"
alb_internal        = false

# EC2 Free Tier: t2.micro or t3.micro (t2.micro is Free Tier eligible in most regions)
instance_type   = "t3.micro"
ec2_instance_type = "t3.micro"
ec2_ami_id          = "ami-0c02fb55956c7d316" # Amazon Linux 2 Free Tier AMI

asg_min_size        = 1
asg_max_size        = 2
asg_desired_capacity = 1