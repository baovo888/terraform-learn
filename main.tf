# Configure the AWS Provider
provider "aws" {
  region = "ap-southeast-2"
}

# 1. Create VPC
# 2. Create IGW
# 3. Create custom route table
# 4. Create a subnet
# 5. Associate subnet with route table
# 6. Create SG to allow port 22, 80, 443
# 7. Create a ENI with IP from step 4
# 8. Assign EIP to ENI created in step 7
# 9. Create Ubuntu server & install apache 2

resource "aws_vpc" "test-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "test vpc"
  }
}


resource "aws_internet_gateway" "test-igw" {
  vpc_id = aws_vpc.test-vpc.id

  tags = {
    Name = "test igw"
  }
}


resource "aws_route_table" "public-rtb" {
  vpc_id = aws_vpc.test-vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test-igw.id
  }

  tags = {
    Name = "Test RTB for public igw"
  }
}


resource "aws_subnet" "test-public-subnet-1" {
  vpc_id     = aws_vpc.test-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-southeast-2a"

  tags = {
    Name = "test-public-subnet"
  }
}


resource "aws_route_table_association" "test-public-rtb-assoc" {
  subnet_id      = aws_subnet.test-public-subnet-1.id
  route_table_id = aws_route_table.public-rtb.id
}


resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.test-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["144.136.36.47/32"]
    ipv6_cidr_blocks = ["144.136.36.47/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web_traffic"
  }
}

resource "aws_network_interface" "test-web-server-nic" {
  subnet_id       = aws_subnet.test-public-subnet-1.id
  private_ips     = ["10.0.1.5"]
  security_groups = [aws_security_group.allow_web.id]
}

resource "aws_eip" "test-web-server-eip" {
  vpc                       = true
  network_interface         = aws_network_interface.test-web-server-nic.id
  associate_with_private_ip = "10.0.1.5"

  depends_on = [aws_internet_gateway.test-igw]
}

resource "aws_instance" "test-webapp" {
  ami = "ami-0e040c48614ad1327"
  instance_type = "t2.micro"

  network_interface {
    network_interface_id = aws_network_interface.test-web-server-nic.id
    device_index         = 0
  }

  key_name = "syd-test"

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install apache2 -y
    sudo systemctl start apache2
    sudo bash -c 'echo our first web server > /var/www/html/index.html'
    EOF

  tags = {
    Name = "first ubuntu server"
  }
  # availability_zone = "ap-southeast-2a"
}