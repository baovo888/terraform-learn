provider "aws" {
  region = "ap-southeast-2"
}

variable vpc_cidr_block {}
variable subnet_pub_cidr_block {}
variable subnet_pri_1_cidr_block {}
variable subnet_pri_2_cidr_block {}
variable avail_zone1 {}
variable avail_zone2 {}
variable instance_type {}
variable env_prefix {}
variable my_ip {}
variable db_username {}
variable db_password {}



resource "aws_vpc" "myapp-vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}


resource "aws_subnet" "myapp-pub-subnet-1" {
    vpc_id = aws_vpc.myapp-vpc.id
    cidr_block = var.subnet_pub_cidr_block
    availability_zone = var.avail_zone1
    tags = {
        Name: "${var.env_prefix}-pub-subnet-1"
    }
}


resource "aws_subnet" "myapp-pri-subnet-1" {
    vpc_id = aws_vpc.myapp-vpc.id
    cidr_block = var.subnet_pri_1_cidr_block
    availability_zone = var.avail_zone1
    tags = {
        Name: "${var.env_prefix}-pri-subnet-1"
    }
}


resource "aws_subnet" "myapp-pri-subnet-2" {
    vpc_id = aws_vpc.myapp-vpc.id
    cidr_block = var.subnet_pri_2_cidr_block
    availability_zone = var.avail_zone2
    tags = {
        Name: "${var.env_prefix}-pri-subnet-2"
    }
}


resource "aws_route_table" "myapp-pub-route-table" {
    vpc_id = aws_vpc.myapp-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-igw.id
    }
    tags = {
        Name = "${var.env_prefix}-pub-rtb"
    }
}


resource "aws_internet_gateway" "myapp-igw" {
    vpc_id = aws_vpc.myapp-vpc.id
    tags = {
        Name = "${var.env_prefix}-igw"
    }
}

resource "aws_route_table_association" "a-rtb-pub-subnet" {
    subnet_id      = aws_subnet.myapp-pub-subnet-1.id
    route_table_id = aws_route_table.myapp-pub-route-table.id
}

resource "aws_security_group" "sg-APP" {
    name = "myapp-app-sg"
    vpc_id = aws_vpc.myapp-vpc.id

    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.my_ip]
    }

    ingress {
        description = "HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]

    }

    tags = {
        Name = "${var.env_prefix}-public-sg"
    }
}


resource "aws_security_group" "sg-DB" {
    name = "myapp-db-sg"
    vpc_id = aws_vpc.myapp-vpc.id

    ingress {
        description = "MySQL"
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = [aws_subnet.myapp-pub-subnet-1.cidr_block]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]

    }

    tags = {
        Name = "${var.env_prefix}-public-sg"
    }
}


resource "aws_iam_role_policy" "ssm-policy" {
    name = "ssm-policy"
    role = aws_iam_role.App-Role.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
            Action = [
                "ssm:*",
            ]
            Effect   = "Allow"
            Resource = "arn:aws:ssm:*:*:parameter/inventory-app/*"
            },
        ]
    })
}


resource "aws_iam_role" "App-Role" {
    name = "App-Role"
    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
            Service = "ec2.amazonaws.com"
        }
        },
    ]
    })
    tags = {
        Name = "${var.env_prefix}-App-Role"
    }
}


resource "aws_iam_instance_profile" "app-role-profile" {
  name = "app-role-profile"
  role = aws_iam_role.App-Role.name
}


resource "aws_db_subnet_group" "db-subnet-group" {
    name       = "main"
    subnet_ids = [aws_subnet.myapp-pri-subnet-1.id,aws_subnet.myapp-pri-subnet-2.id]

    tags = {
        Name = "My DB subnet group"
    }
}


resource "aws_db_instance" "db-Aurora" {
    identifier           = "bao-db"
    instance_class       = "db.t2.small"
    allocated_storage    = 5
    engine               = "mysql"
    engine_version       = "5.7"
    db_subnet_group_name = aws_db_subnet_group.db-subnet-group.id
    username             = var.db_username
    password             = var.db_password
    parameter_group_name = "default.mysql5.7"
    skip_final_snapshot  = true
    vpc_security_group_ids = [aws_security_group.sg-DB.id]
}


output "rds_hostname" {
    description = "RDS instance hostname"
    value       = aws_db_instance.db-Aurora.address
}


output "rds_port" {
    description = "RDS instance port"
    value       = aws_db_instance.db-Aurora.port
}


output "rds_username" {
    description = "RDS instance root username"
    value       = aws_db_instance.db-Aurora.username
}


data "aws_ami" "latest-amazon-linux-image" {
    most_recent = true
    owners = ["amazon"]
    filter {
        name = "name"
        values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}


resource "aws_instance" "myapp-server" {
    ami = data.aws_ami.latest-amazon-linux-image.id
    instance_type = var.instance_type

    subnet_id = aws_subnet.myapp-pub-subnet-1.id
    vpc_security_group_ids = [aws_security_group.sg-APP.id]
    availability_zone = var.avail_zone1

    associate_public_ip_address = true
    iam_instance_profile = aws_iam_instance_profile.app-role-profile.name
    key_name = "syd-test"
    user_data = file("webserver-script.sh")

    tags = {
        Name = "${var.env_prefix}-Web-App-Server"
    }
}


output "aws_ami_id" {
    value = data.aws_ami.latest-amazon-linux-image.id
}


output "aws_webserver_public_id" {
    value = aws_instance.myapp-server.public_ip
}


