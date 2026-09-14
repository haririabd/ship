# GitHub Actions → AWS ECR via OIDC

How this repo's CI authenticates to AWS without storing any access keys, and
how to extend it later.

## What exists today (account `739951718815`, region `ap-southeast-1`)

- **OIDC provider**: `arn:aws:iam::739951718815:oidc-provider/token.actions.githubusercontent.com`
  (one per AWS account — shared by every repo/role that federates with GitHub)
- **IAM role**: `arn:aws:iam::739951718815:role/github-actions-ecr-push`
  - Trust policy: only assumable by GitHub Actions runs on
    `repo:haririabd/ship:ref:refs/heads/main`
  - Permissions: push-only access (`ecr:PutImage`, `ecr:InitiateLayerUpload`,
    `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`,
    `ecr:BatchCheckLayerAvailability`) scoped to
    `arn:aws:ecr:ap-southeast-1:739951718815:repository/devops-bootcamp/haririabd`,
    plus `ecr:GetAuthorizationToken` (this action doesn't support resource
    scoping, so it's `Resource: "*"`)
- Workflow: [`.github/workflows/push-to-ecr.yml`](../.github/workflows/push-to-ecr.yml)
  uses `role-to-assume` with this role — no `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`
  secrets involved.

## Adding another repo later

Two independent things to widen, depending on what "another repo" means:

### A. Another GitHub repo should be able to push to the *same* ECR repo

Edit the role's **trust policy** to allow more than one `sub`. Swap
`StringLike` from a single string to a list:

```bash
aws iam update-assume-role-policy \
  --role-name github-actions-ecr-push \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::739951718815:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:haririabd/ship:ref:refs/heads/main",
            "repo:haririabd/<new-repo>:ref:refs/heads/main"
          ]
        }
      }
    }]
  }'
```

### B. This repo (or the new one) needs to push to a *different/new* ECR repository

Edit the role's **permissions policy** (`ecr-push-devops-bootcamp-haririabd`)
to add the new repo's ARN as a second entry in the `Resource` list of the
`EcrPushShipRepo` statement:

```bash
aws iam put-role-policy \
  --role-name github-actions-ecr-push \
  --policy-name ecr-push-devops-bootcamp-haririabd \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "EcrAuth",
        "Effect": "Allow",
        "Action": "ecr:GetAuthorizationToken",
        "Resource": "*"
      },
      {
        "Sid": "EcrPushShipRepo",
        "Effect": "Allow",
        "Action": [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ],
        "Resource": [
          "arn:aws:ecr:ap-southeast-1:739951718815:repository/devops-bootcamp/haririabd",
          "arn:aws:ecr:ap-southeast-1:739951718815:repository/<new-ecr-repo-name>"
        ]
      }
    ]
  }'
```

(`put-role-policy` overwrites the named inline policy wholesale — always
include every statement you want to keep, not just the new one.)

### Preferred alternative for "a whole new project"

Rather than growing one role to cover unrelated repos/pipelines, create a
**second role** (own trust policy scoped to the new repo, own permissions
policy scoped to its own ECR repo) instead of widening this one. Keeps the
blast radius of each role limited to what it's actually authorized for.

## Sanity checks

```bash
# who/what can assume the role
aws iam get-role --role-name github-actions-ecr-push --query 'Role.AssumeRolePolicyDocument'

# what the role can actually do
aws iam get-role-policy --role-name github-actions-ecr-push \
  --policy-name ecr-push-devops-bootcamp-haririabd
```
