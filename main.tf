#Create a VPC with CIDR 10.0.0.0/16

resource "aws_vpc" "my_vpc_exam" {
  cidr_block = var.vpc_cidr
}

#Create a Public Subnet (10.0.1.0/24)
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.my_vpc_exam.id
  cidr_block        = var.public_subnet_cidr
  availability_zone       = "ca-central-1a"
}

#Create a Private Subnet (10.0.2.0/24)
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_vpc_exam.id
  cidr_block = var.private_subnet_cidr
}

#Create a Internet Gateway
resource "aws_internet_gateway" "my_gateway" {
  vpc_id = aws_vpc.my_vpc_exam.id

  tags = {
    Name = "main"
  }
}

# Create a Route Table for Public Subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc_exam.id

  # Route all outbound traffic (0.0.0.0/0) to the Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"  
    gateway_id = aws_internet_gateway.my_gateway.id
  }
}

#Associate Public Subnet with Route Table
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

#Create a Security Group for ec2
resource "aws_security_group" "my_web_sg" {
  vpc_id = aws_vpc.my_vpc_exam.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Create a EC2 Instance
resource "aws_instance" "my_ec2_web" {
  ami             = "ami-0db18496905e01e3d"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.my_web_sg.id]
  key_name        = "my-key-pair"
}

# Get the current AWS account ID
data "aws_caller_identity" "current" {}

# Step 1: Create KMS Key Without Policy
resource "aws_kms_key" "s3_kms" {
  description             = "My KMS key"
  enable_key_rotation     = true
  deletion_window_in_days = 20
}

# Step 2: Attach KMS Policy Separately
resource "aws_kms_key_policy" "s3_kms_policy" {
  key_id = aws_kms_key.s3_kms.id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-default-1"
    Statement = [
      {
        Sid       = "EnableIAMUserPermissions"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = aws_kms_key.s3_kms.arn
      },
      {
        Sid       = "AllowAdministration"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform"
        }
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ]
        Resource = aws_kms_key.s3_kms.arn
      },
      {
        Sid       = "AllowKeyUsage"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform"
        }
        Action = [
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext"
        ]
        Resource = aws_kms_key.s3_kms.arn
      }
    ]
  })
}

#Create a S3 Bucket
resource "aws_s3_bucket" "exams_logs_0944" {
  bucket = "my-log-bucket-name"
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.s3_kms.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

#Create a DynamoDB Table
resource "aws_dynamodb_table" "session_storage" {
  name         = "session-store"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }
}