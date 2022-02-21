resource "aws_s3_bucket" "bucket" {
  bucket = "lakind-hewawasam-article-terraform-state-backend"
  object_lock_configuration {
    object_lock_enabled = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform-lock" {
  name           = "terraform_state"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    Name = "terraform-lock"
  }
}

terraform {
  backend "s3" {
    bucket         = "lakind-hewawasam-article-terraform-state-backend"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform_state"
  }
}
