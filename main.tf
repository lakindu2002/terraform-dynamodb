terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["$HOME/.aws/credentials"]
}

resource "aws_dynamodb_table" "tf_notes_table" {
  name           = "tf-notes-table"
  billing_mode   = "PROVISIONED"
  read_capacity  = "30"
  write_capacity = "30"
  attribute {
    name = "noteId"
    type = "S"
  }
  hash_key = "noteId"
  // adding the TTL on DynamoDB Table
  ttl {
    enabled        = true           // enabling TTL
    attribute_name = "expiryPeriod" // the attribute name which enforces TTL, must be a Number (Timestamp)
  }
  // configuring Point in Time Recovery 
  point_in_time_recovery {
    enabled = true
  }
  // configure encryption at REST
  server_side_encryption {
    enabled = true // false -> use AWS Owned CMK, true -> use AWS Managed CMK, true + key arn -> use custom key
  }
  lifecycle {
    ignore_changes = [
      "write_capacity", "read_capacity"
    ]
  }
}

module "table_autoscaling" {
  source     = "snowplow-devops/dynamodb-autoscaling/aws" // add the autoscaling module
  table_name = aws_dynamodb_table.tf_notes_table.name     // apply autoscaling for the tf_notes_table
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dynamodb-lambda-policy" {
  name = "dynamodb_lambda_policy"
  role = aws_iam_role.iam_for_lambda.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : ["dynamodb:*"],
        "Resource" : "${aws_dynamodb_table.tf_notes_table.arn}"
      }
    ]
  })
}

data "archive_file" "create-note-archive" {
  source_file = "lambdas/create-note.js"
  output_path = "lambdas/create-note.zip"
  type        = "zip"
}

resource "aws_lambda_function" "create-note" {
  environment {
    variables = {
      NOTES_TABLE = aws_dynamodb_table.tf_notes_table.name
    }
  }
  memory_size   = "128"
  timeout       = 10
  runtime       = "nodejs14.x"
  architectures = ["arm64"]
  handler       = "lambdas/create-note.handler"
  function_name = "create-note"
  role          = aws_iam_role.iam_for_lambda.arn
  filename      = "lambdas/create-note.zip"
}

data "archive_file" "delete-note-archive" {
  source_file = "lambdas/delete-note.js"
  output_path = "lambdas/delete-note.zip"
  type        = "zip"
}

resource "aws_lambda_function" "delete-note" {
  environment {
    variables = {
      NOTES_TABLE = aws_dynamodb_table.tf_notes_table.name
    }
  }
  memory_size   = "128"
  timeout       = 10
  runtime       = "nodejs14.x"
  architectures = ["arm64"]
  handler       = "lambdas/delete-note.handler"
  function_name = "delete-note"
  role          = aws_iam_role.iam_for_lambda.arn
  filename      = "lambdas/delete-note.zip"
}

data "archive_file" "get-all-notes-archive" {
  source_file = "lambdas/get-all-notes.js"
  output_path = "lambdas/get-all-notes.zip"
  type        = "zip"
}


resource "aws_lambda_function" "get-all-notes" {
  environment {
    variables = {
      NOTES_TABLE = aws_dynamodb_table.tf_notes_table.name
    }
  }
  memory_size   = "128"
  timeout       = 10
  runtime       = "nodejs14.x"
  architectures = ["arm64"]
  handler       = "lambdas/get-all-notes.handler"
  function_name = "get-all-notes"
  role          = aws_iam_role.iam_for_lambda.arn
  filename      = "lambdas/get-all-notes.zip"
}
