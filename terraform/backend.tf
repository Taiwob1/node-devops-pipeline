terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket44"
    key            = "project/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}