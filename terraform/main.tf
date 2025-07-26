# ---------- Provider Configuration ----------
provider "aws" {
  region = var.region
}

# ---------- VPC ----------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "ecommerce-vpc"
  }
}

# ---------- Public Subnet ----------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"
  tags = {
    Name = "ecommerce-public-subnet"
  }
}

# ---------- Internet Gateway ----------
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "ecommerce-igw"
  }
}

# ---------- Route Table ----------
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "ecommerce-rt"
  }
}

# ---------- Associate Route Table ----------
resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}

# ---------- Security Group ----------
resource "aws_security_group" "instance_sg" {
  name        = "ecommerce-sg"
  description = "Allow HTTP and service ports"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Frontend"
    from_port   = 3000
    to_port     = 3004
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 🔒 Can restrict to your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecommerce-sg"
  }
}

# ---------- Get Ubuntu AMI ----------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical Ubuntu official

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ---------- EC2 Instance ----------
resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y docker.io
              systemctl start docker
              systemctl enable docker

              # Clean up old containers
              docker rm -f frontend user products orders cart || true

              # Run containers
              docker run -d -p 3001:3001 --restart unless-stopped --name user vignesh342/user-service
              docker run -d -p 3002:3002 --restart unless-stopped --name products vignesh342/products-service
              docker run -d -p 3003:3003 --restart unless-stopped --name orders vignesh342/orders-service
              docker run -d -p 3004:3004 --restart unless-stopped --name cart vignesh342/cart-service
              docker run -d -p 3000:3000 --restart unless-stopped --name frontend vignesh342/frontend-service
              EOF

  tags = {
    Name = "ecommerce-app"
  }
}
