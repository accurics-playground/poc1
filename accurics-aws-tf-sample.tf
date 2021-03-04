provider "aws" {
  access_key = "AKIARWXIFOVSRLGCGYSV" //nitish@accurics.com
  secret_key = "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"
  region     = "us-west-2" //Canada
}

# Create a VPC to launch our instances into
resource "aws_vpc" "accurics-test-vpc1" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name         = format("%s-vpc1", var.acqaPrefix)
    ACQAResource = "true"
    Owner        = "Accurics"
  }
}

# Create a security group with most of the vulnerabilities
resource "aws_security_group" "accurics-test-securitygroup1" {
  name        = "accurics-test-securitygroup1"
  description = "This security group is for API test automation"
  vpc_id      = aws_vpc.accurics-test-vpc1.id

  tags = {
    Name         = format("%s-securitygroup1", var.acqaPrefix)
    ACQAResource = "true"
    Owner        = "Accurics"
  }

  # SSH access from anywhere..
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["<cidr>"]
  }


  # HTTP access from the VPC - changed
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["<cidr>"]
  }

  ingress {
    to_port     = 3306
    from_port   = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/24"]
  }

  # Drift 2
  ingress {
    to_port     = 3333
    from_port   = 3333
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/24"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/24"]
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "accurics-test-gateway1" {
  vpc_id = aws_vpc.accurics-test-vpc1.id
  tags = {
    Name         = format("%s-gateway1", var.acqaPrefix)
    ACQAResource = "true"
    Owner        = "Accurics"
  }
}

# Create a subnet to launch our instances into
resource "aws_subnet" "accurics-test-subnet1" {
  vpc_id                  = aws_vpc.accurics-test-vpc1.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name         = format("%s-subnet1", var.acqaPrefix)
    ACQAResource = "true"
    Owner        = "Accurics"
  }
}

# Create network interface
resource "aws_network_interface" "accurics-test-networkinterface1" {
  subnet_id       = aws_subnet.accurics-test-subnet1.id
  private_ips     = ["10.0.0.50"]
  security_groups = [aws_security_group.accurics-test-securitygroup1.id]

  # attachment {
  #   instance     = aws_instance.accurics-test-instance1.id
  #   device_index = 1
  # }
  tags = {
    Name         = format("%s-networkinterface1", var.acqaPrefix)
    ACQAResource = "true"
    Owner        = "Accurics"
  }
}

# Get the userID for s3 bucket
data "aws_canonical_user_id" "current_user" {}

# Create S3 bucket
resource "aws_s3_bucket" "accurics-test-s3bucket1" {
  bucket = "accurics-test-s3bucket1"

  grant {
    id          = data.aws_canonical_user_id.current_user.id
    type        = "CanonicalUser"
    permissions = ["FULL_CONTROL"]
  }

  grant {
    type        = "Group"
    permissions = ["READ", "WRITE"]
    uri         = "http://acs.amazonaws.com/groups/s3/LogDelivery"
  }

  tags = {
    Name         = format("%s-s3bucket1", var.acqaPrefix)
    ACQAResource = "true"
    Owner        = "Accurics"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }
}

# Cloudwatch log group and stream
resource "aws_cloudwatch_log_group" "accurics-test-cwlg1" {
  name = "accurics-test-cwlg1"

  # Tags
  tags = {
    Name         = format("%s-cwlg1", var.acqaPrefix)
    ACQAResource = "true"
    Owner        = "Accurics"
  }
  retention_in_days = "<retention_in_days>"
}
resource "aws_cloudwatch_log_stream" "accurics-test-cwstream1" {
  name           = "accurics-test-cwstream1"
  log_group_name = aws_cloudwatch_log_group.accurics-test-cwlg1.name
}


#Create EC2
data "aws_ami" "accurics-test-instance1-ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# KMS Key
resource "aws_kms_key" "accurics-test-kmskey1" {
  description             = "accurics-test-kmskey1"
  deletion_window_in_days = 30
  tags = {
    Name         = format("%s-kmskey1", var.acqaPrefix)
    ACQAResource = "true"
    Owner        = "Accurics"
  }
  enable_key_rotation = true
}

# # ebs volume
# resource "aws_ebs_volume" "accurics-test-ebsvolume1" {
#   availability_zone = "us-west-2b"
#   size              = 25
#   encrypted         = false
#   tags = {
#     Name = format("%s-ebsvolume1", var.acqaPrefix)
#     ACQAResource = "true"
#     Owner = "Accurics"
#   }
# }

# EIP
resource "aws_eip" "accurics-test-eip1" {
  vpc                       = true
  network_interface         = aws_network_interface.accurics-test-networkinterface1.id
  associate_with_private_ip = "10.0.0.50"
  tags = {
    Name         = format("%s-eip1", var.acqaPrefix)
    ACQAResource = "true"
    Owner        = "Accurics"
  }
}

# # ec2
# resource "aws_instance" "accurics-test-instance1" {
#   ami           = data.aws_ami.accurics-test-instance1-ami.id
#   instance_type = "t2.micro"

#    network_interface {
#     network_interface_id = aws_network_interface.accurics-test-networkinterface1.id
#     device_index         = 0
#   } 

#   tags = {
#     Name = format("%s-instance1", var.acqaPrefix)
#     ACQAResource = "true"
#     Owner = "Accurics"
#   }
# }

# Start -------------- Dynamodb table
resource "aws_dynamodb_table" "accurics-test-dynamodbtable1" {
  name             = "accurics-test-dynamodbtable1"
  hash_key         = "TestTableHashKey"
  billing_mode     = "PROVISIONED"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "TestTableHashKey"
    type = "S"
  }
  server_side_encryption {
    enabled = false
  }
  tags = {
    Name         = format("%s-dynamodbtable1", var.acqaPrefix)
    ACQAResource = "true"
    Owner        = "Accurics"
  }
  point_in_time_recovery = "{\n    \"point_in_time_recovery\": {\n        \"enabled\": true\n    }\n}"
}

# Codecommit
resource "aws_codecommit_repository" "accurics-test-ccrepo1" {
  repository_name = "accurics-test-ccrepo1"
  description     = "accurics-test-ccrepo1"
  tags = {
    Name         = format("%s-cloudfront1", var.acqaPrefix)
    ACQAResource = "true"
    Owner        = "Accurics"
  }
}


resource "aws_s3_bucket_policy" "accurics-test-s3bucket1Policy" {
  bucket = "${aws_s3_bucket.accurics-test-s3bucket1.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "accurics-test-s3bucket1-restrict-access-to-users-or-roles",
      "Effect": "Allow",
      "Principal": [
        {
          "AWS": [
            "arn:aws:iam::##acount_id##:role/##role_name##",
            "arn:aws:iam::##acount_id##:user/##user_name##"
          ]
        }
      ],
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.accurics-test-s3bucket1.id}/*"
    }
  ]
}
POLICY
}
resource "aws_flow_log" "accurics-test-vpc1" {
  vpc_id          = "${aws_vpc.accurics-test-vpc1.id}"
  iam_role_arn    = "##arn:aws:iam::111111111111:role/sample_role##"
  log_destination = "${aws_s3_bucket.accurics-test-vpc1.arn}"
  traffic_type    = "ALL"

  tags = {
    GeneratedBy      = "Accurics"
    ParentResourceId = "aws_vpc.accurics-test-vpc1"
  }
}
resource "aws_s3_bucket" "accurics-test-vpc1" {
  bucket        = "accurics-test-vpc1_flow_log_s3_bucket"
  acl           = "private"
  force_destroy = true

  versioning {
    enabled    = true
    mfa_delete = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
resource "aws_s3_bucket_policy" "accurics-test-vpc1" {
  bucket = "${aws_s3_bucket.accurics-test-vpc1.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "accurics-test-vpc1-restrict-access-to-users-or-roles",
      "Effect": "Allow",
      "Principal": [
        {
          "AWS": [
            "arn:aws:iam::##acount_id##:role/##role_name##",
            "arn:aws:iam::##acount_id##:user/##user_name##"
          ]
        }
      ],
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.accurics-test-vpc1.id}/*"
    }
  ]
}
POLICY
}