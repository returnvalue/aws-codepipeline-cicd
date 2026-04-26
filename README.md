# AWS CI/CD Pipeline Automation Lab

This lab demonstrates a foundational CloudOps pattern: automating the software delivery lifecycle using **AWS CodePipeline** and **AWS CodeBuild**.

## Architecture Overview

The system implements a multi-stage automated deployment pipeline:

1.  **Artifact Storage:** An S3 bucket serves as the centralized repository for pipeline artifacts and the initial source code.
2.  **Source Stage:** CodePipeline monitors a specific S3 object (`source.zip`). When an update is detected, it triggers the pipeline.
3.  **Build Stage:** AWS CodeBuild provisions a managed build environment, executes the instructions defined in the `buildspec`, and generates a build output.
4.  **Orchestration:** CodePipeline manages the transition between stages, handling artifact passing and IAM-based security throughout the workflow.

## Key Components

-   **AWS CodePipeline:** The continuous delivery service that models and automates the release process.
-   **AWS CodeBuild:** The fully managed build service that compiles source code and runs tests.
-   **IAM Roles:** Dedicated roles for CodePipeline and CodeBuild, following the principle of least privilege.
-   **S3 Artifact Store:** Durable storage for data passing between pipeline stages.

## Prerequisites

-   [Terraform](https://www.terraform.io/downloads.html)
-   [LocalStack Pro](https://localstack.cloud/)
-   [AWS CLI / awslocal](https://github.com/localstack/awscli-local)

## Deployment

1.  **Initialize and Apply:**
    ```bash
    terraform init
    terraform apply -auto-approve
    ```

## Verification & Testing

To test the CI/CD automation:

1.  **Prepare Source Code:**
    Create a simple source file and zip it:
    ```bash
    echo "v1.0" > app.txt
    zip source.zip app.txt
    ```

2.  **Trigger the Pipeline:**
    Upload the source zip to the artifact bucket:
    ```bash
    awslocal s3 cp source.zip s3://cicd-pipeline-artifacts-bucket/source.zip
    aws s3 cp source.zip s3://cicd-pipeline-artifacts-bucket/source.zip
    ```

3.  **Monitor Pipeline Progress:**
    Check the status of the pipeline execution:
    ```bash
    awslocal codepipeline get-pipeline-state --name sysops-automation-pipeline
    aws codepipeline get-pipeline-state --name sysops-automation-pipeline
    ```

4.  **Confirm Build Output:**
    Once the pipeline finishes, check the S3 bucket for the generated build artifact.

## Cleanup

To tear down the infrastructure:
```bash
terraform destroy -auto-approve
```

---

💡 **Pro Tip: Using `aws` instead of `awslocal`**

If you prefer using the standard `aws` CLI without the `awslocal` wrapper or repeating the `--endpoint-url` flag, you can configure a dedicated profile in your AWS config files.

### 1. Configure your Profile
Add the following to your `~/.aws/config` file:
```ini
[profile localstack]
region = us-east-1
output = json
# This line redirects all commands for this profile to LocalStack
endpoint_url = http://localhost:4566
```

Add matching dummy credentials to your `~/.aws/credentials` file:
```ini
[localstack]
aws_access_key_id = test
aws_secret_access_key = test
```

### 2. Use it in your Terminal
You can now run commands in two ways:

**Option A: Pass the profile flag**
```bash
aws iam create-user --user-name DevUser --profile localstack
```

**Option B: Set an environment variable (Recommended)**
Set your profile once in your session, and all subsequent `aws` commands will automatically target LocalStack:
```bash
export AWS_PROFILE=localstack
aws iam create-user --user-name DevUser
```

### Why this works
- **Precedence**: The AWS CLI (v2) supports a global `endpoint_url` setting within a profile. When this is set, the CLI automatically redirects all API calls for that profile to your local container instead of the real AWS cloud.
- **Convenience**: This allows you to use the standard documentation commands exactly as written, which is helpful if you are copy-pasting examples from AWS labs or tutorials.
