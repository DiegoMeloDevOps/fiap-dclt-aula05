# ============================================
# TERRAFORM CONFIGURATION
# ============================================
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket  = "fiap-terraform-state-dev-diego"
    key     = "development/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

# ============================================
# AWS PROVIDER CONFIGURATION
# ============================================
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "development"
      Project     = "fiap-cicd"
      ManagedBy   = "terraform"
      Owner       = "fiap-devops-team"
    }
  }
}

# ============================================
# DATA SOURCES
# ============================================
data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================
# VPC
# ============================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "fiap-cicd-dev-vpc"
  }
}

# ============================================
# INTERNET GATEWAY
# ============================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "fiap-cicd-dev-igw"
  }
}

# ============================================
# PUBLIC SUBNETS
# ============================================
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "fiap-cicd-dev-public-${count.index + 1}"
  }
}

# ============================================
# ROUTE TABLE - PUBLIC
# ============================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "fiap-cicd-dev-public-rt"
  }
}

# ============================================
# ROUTE TABLE ASSOCIATIONS
# ============================================
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ============================================
# RANDOM STRING (para nome único do bucket)
# ============================================
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# ============================================
# S3 BUCKET FOR ARTIFACTS
# ============================================
resource "aws_s3_bucket" "artifacts" {
  bucket = "fiap-cicd-dev-artifacts-${random_string.suffix.result}"

  tags = {
    Name = "fiap-cicd-dev-artifacts"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}# Deploy test Mon Feb 23 20:31:22 -03 2026
