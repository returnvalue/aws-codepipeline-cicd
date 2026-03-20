# AWS provider configuration for LocalStack
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    apigateway     = "http://localhost:4566"
    codebuild      = "http://localhost:4566"
    codepipeline   = "http://localhost:4566"
    iam            = "http://localhost:4566"
    s3             = "http://s3.localhost.localstack.cloud:4566"
    sts            = "http://localhost:4566"
  }
}

# S3 Bucket: Stores our pipeline artifacts (build outputs, etc.)
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "cicd-pipeline-artifacts-bucket"
  force_destroy = true

  tags = {
    Name        = "pipeline-artifacts"
    Environment = "CloudOps-Lab"
  }
}

# IAM Role: Identity for CodeBuild to execute builds
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

# IAM Policy: Grants CodeBuild permission to write logs and access S3
resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["s3:GetObject", "s3:PutObject"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.pipeline_artifacts.arn}/*"
      }
    ]
  })
}

# CodeBuild Project: Defines our build environment and commands
resource "aws_codebuild_project" "app_build" {
  name          = "sysops-app-build"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type = "CODEPIPELINE"
    buildspec = <<-BUILD_SPEC
      version: 0.2
      phases:
        build:
          commands:
            - echo Building the application...
            - date > build_info.txt
      artifacts:
        files:
          - build_info.txt
    BUILD_SPEC
  }
}

# IAM Role: Identity for CodePipeline to orchestrate the workflow
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
    }]
  })
}

# IAM Policy: Grants CodePipeline permission to use S3 and trigger CodeBuild
resource "aws_iam_role_policy" "codepipeline_policy" {
  role = aws_iam_role.codepipeline_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetObject", "s3:PutObject"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.pipeline_artifacts.arn}/*"
      },
      {
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Effect   = "Allow"
        Resource = aws_codebuild_project.app_build.arn
      }
    ]
  })
}

# CodePipeline: The orchestration engine for our CI/CD workflow
resource "aws_codepipeline" "cicd_pipeline" {
  name     = "sysops-automation-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "SourceAction"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        S3Bucket    = aws_s3_bucket.pipeline_artifacts.bucket
        S3ObjectKey = "source.zip"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "BuildAction"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.app_build.name
      }
    }
  }
}

# Outputs: Key identifiers for the CI/CD pipeline
output "pipeline_name" {
  value = aws_codepipeline.cicd_pipeline.name
}

output "artifact_bucket" {
  value = aws_s3_bucket.pipeline_artifacts.id
}
