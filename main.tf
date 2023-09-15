
provider "aws" {
  region = "us-east-1" # Replace with your desired region
}

terraform {
  backend "s3" {
    bucket         = "lambda-redis-test-1000"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

# Define a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16" # Replace with your desired CIDR block
}

# Define a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24" # Replace with your desired CIDR block for the public subnet
  availability_zone       = "us-east-1a" # Replace with your desired availability zone
  map_public_ip_on_launch = true
}

# Create an Internet Gateway and attach it to the VPC
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

# # # Create a Route Table for public subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

# # Associate the public subnet with the public route table
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Define a security group for the EC2 instance
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2-security-group"
  description = "Security group for the EC2 instance"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Adjust this to your trusted IP or CIDR block
  }

  # # Define inbound rule for port 6379 (Redis)
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Define an EC2 instance
resource "aws_instance" "ec2_instance" {
  ami           = "ami-0793d6f1bd8ddb11c" # Replace with your desired AMI ID
  instance_type = "t2.micro"              # Replace with your desired instance type
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name      = "my-local-2"

  tags = {
    Name = "ExampleInstance"
  }
}

# Create a null_resource to run remote-exec
resource "null_resource" "remote_exec" {
  triggers = {
    # You can add dependencies here if needed
    instance_id = aws_instance.ec2_instance.id
  }

  # Use the provisioner to execute remote commands
  provisioner "remote-exec" {
    inline = [
      "sudo service docker start",
      "sudo chmod 666 /var/run/docker.sock",
      "docker run -d -p 6379:6379 --name my-redis redis:alpine --requirepass ${var.REDIS_PASS}"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"  # Replace with the SSH user for your AMI
      private_key = "${file("~/.ssh/id_rsa")}"  # Replace with the path to your SSH private key
      host        = aws_instance.ec2_instance.public_ip
    }
  }
}

# Define an AWS Lambda function
resource "aws_lambda_function" "my_lambda" {
  function_name = "my-lambda-function"
  handler      = "index.handler"
  runtime      = "nodejs18.x" # Replace with your desired runtime
  role         = "arn:aws:iam::344965508130:role/my_lambda_role" # Replace with your IAM role ARN
  filename     = "lambda_function_${var.lambdasVersion}.zip"

  environment {
    variables = {
      REDIS_HOST = aws_instance.ec2_instance.public_ip # Use the private IP of the EC2 instance
      REDIS_PORT = 6379
      REDIS_PASS = "${var.REDIS_PASS}"
      REDIS_DB_PATH = "${var.REDIS_DB_PATH}"
    }
  }
}

variable "lambdasVersion" {
  type        = string
  description = "version of the lambdas zip on S3"
}

variable "REDIS_DB_PATH" {
  type        = string
  description = "Redis DB Path"
}

variable "REDIS_PASS" {
  type        = string
  description = "Redis EC2 DB Pass"
}
