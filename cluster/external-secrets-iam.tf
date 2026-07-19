locals {
  external_secrets_oidc_provider_url_without_scheme = replace(
    aws_iam_openid_connect_provider.eks.url,
    "https://",
    ""
  )
}

data "aws_iam_policy_document" "external_secrets_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type = "Federated"
      identifiers = [
        aws_iam_openid_connect_provider.eks.arn
      ]
    }

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    condition {
      test     = "StringEquals"
      variable = "${local.external_secrets_oidc_provider_url_without_scheme}:sub"

      values = [
        "system:serviceaccount:${var.external_secrets_namespace}:${var.external_secrets_service_account_name}"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.external_secrets_oidc_provider_url_without_scheme}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }
  }
}

data "aws_iam_policy_document" "external_secrets_read" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = values(var.secret_container_arns)
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.project_name}-external-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role.json

  tags = {
    Name = "${var.project_name}-external-secrets-role"
  }
}

resource "aws_iam_policy" "external_secrets_read" {
  name        = "${var.project_name}-external-secrets-read-secrets-policy"
  description = "Allows External Secrets Operator to read approved Secrets Manager secrets"
  policy      = data.aws_iam_policy_document.external_secrets_read.json

  tags = {
    Name = "${var.project_name}-external-secrets-read-secrets-policy"
  }
}

resource "aws_iam_role_policy_attachment" "external_secrets_read" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets_read.arn
}
