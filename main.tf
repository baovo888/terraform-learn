provider "aws" {
  region = "ap-southeast-2"
}

variable vpc_cidr_block {}
variable subnet_pub_cidr_block {}
variable subnet_pri_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}


resource "aws_vpc" "myapp-vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}


resource "aws_subnet" "myapp-pub-subnet-1" {
    vpc_id = aws_vpc.myapp-vpc.id
    cidr_block = var.subnet_pub_cidr_block
    availability_zone = var.avail_zone
    tags = {
        Name: "${var.env_prefix}-pub-subnet-1"
    }
}


resource "aws_subnet" "myapp-pri-subnet-1" {
    vpc_id = aws_vpc.myapp-vpc.id
    cidr_block = var.subnet_pri_cidr_block
    availability_zone = var.avail_zone
    tags = {
        Name: "${var.env_prefix}-pri-subnet-1"
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
    subnet_id      = aws_subnet.myapp-pri-subnet-1.id
    route_table_id = aws_route_table.myapp-pub-route-table.id
}

resource "aws_security_group" "allow_web" {
    name = "myapp-pub-sg"
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