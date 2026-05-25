locals {
  karpenter_discovery_tag_key = "karpenter.sh/discovery"
  oidc_provider_url_without_scheme = replace(
    aws_iam_openid_connect_provider.eks.url,
    "https://",
    ""
  )
}

# ------------------------------------------------------------
# Karpenter Controller IAM Role
# - Karpenter Pod가 AWS EC2 API를 호출할 때 사용하는 Role
# ------------------------------------------------------------

data "aws_iam_policy_document" "karpenter_controller_assume_role" {
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
      variable = "${local.oidc_provider_url_without_scheme}:sub"

      values = [
        "system:serviceaccount:${var.karpenter_namespace}:karpenter"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url_without_scheme}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "karpenter_controller" {
  name               = "${var.project_name}-karpenter-controller-role"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume_role.json

  tags = {
    Name = "${var.project_name}-karpenter-controller-role"
  }
}

# ------------------------------------------------------------
# Karpenter Node IAM Role
# - Karpenter가 생성하는 EC2 Node가 사용하는 Role
# ------------------------------------------------------------

data "aws_iam_policy_document" "karpenter_node_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com"
      ]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role" "karpenter_node" {
  name               = "KarpenterNodeRole-${aws_eks_cluster.main.name}"
  assume_role_policy = data.aws_iam_policy_document.karpenter_node_assume_role.json

  tags = {
    Name = "KarpenterNodeRole-${aws_eks_cluster.main.name}"
  }
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker_node_policy" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni_policy" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr_readonly" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "karpenter_node" {
  name = "KarpenterNodeInstanceProfile-${aws_eks_cluster.main.name}"
  role = aws_iam_role.karpenter_node.name

  tags = {
    Name = "KarpenterNodeInstanceProfile-${aws_eks_cluster.main.name}"
  }
}

# ------------------------------------------------------------
# Karpenter Node Role을 EKS Node로 join 가능하게 허용
# ------------------------------------------------------------

resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX"

  depends_on = [
    aws_eks_cluster.main
  ]
}

# ------------------------------------------------------------
# Interruption Queue
# - 처음은 On-Demand로 테스트해도 되지만, Spot/Interruption 실습까지 고려해 미리 생성
# ------------------------------------------------------------

resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = aws_eks_cluster.main.name
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = {
    Name = "${aws_eks_cluster.main.name}-karpenter-interruption-queue"
  }
}

data "aws_iam_policy_document" "karpenter_interruption_queue" {
  statement {
    sid    = "AllowEventBridgeToSendMessage"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com",
        "sqs.amazonaws.com"
      ]
    }

    actions = [
      "sqs:SendMessage"
    ]

    resources = [
      aws_sqs_queue.karpenter_interruption.arn
    ]
  }

  statement {
    sid    = "DenyHTTP"
    effect = "Deny"

    principals {
      type = "*"
      identifiers = [
        "*"
      ]
    }

    actions = [
      "sqs:*"
    ]

    resources = [
      aws_sqs_queue.karpenter_interruption.arn
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values = [
        "false"
      ]
    }
  }
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id
  policy    = data.aws_iam_policy_document.karpenter_interruption_queue.json
}

resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  name = "${var.project_name}-karpenter-spot-interruption"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_rule" "karpenter_rebalance" {
  name = "${var.project_name}-karpenter-rebalance"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
}

resource "aws_cloudwatch_event_rule" "karpenter_instance_state_change" {
  name = "${var.project_name}-karpenter-instance-state-change"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_rule" "karpenter_scheduled_change" {
  name = "${var.project_name}-karpenter-scheduled-change"

  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  rule = aws_cloudwatch_event_rule.karpenter_spot_interruption.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_target" "karpenter_rebalance" {
  rule = aws_cloudwatch_event_rule.karpenter_rebalance.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state_change" {
  rule = aws_cloudwatch_event_rule.karpenter_instance_state_change.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_target" "karpenter_scheduled_change" {
  rule = aws_cloudwatch_event_rule.karpenter_scheduled_change.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

# ------------------------------------------------------------
# Karpenter Controller IAM Policy
# - 학습용 1차 정책
# - 동작 확인 후 공식 CloudFormation 수준으로 더 좁힐 수 있음
# ------------------------------------------------------------

data "aws_iam_policy_document" "karpenter_controller" {
  statement {
    sid    = "AllowEC2ReadActions"
    effect = "Allow"

    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeCapacityReservations",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribePlacementGroups",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "ssm:GetParameter",
      "pricing:GetProducts",
      "iam:GetInstanceProfile"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowUnscopedInstanceProfileListAction"
    effect = "Allow"

    actions = [
      "iam:ListInstanceProfiles"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowEKSClusterDescribe"
    effect = "Allow"

    actions = [
      "eks:DescribeCluster"
    ]

    resources = [
      aws_eks_cluster.main.arn
    ]
  }

  statement {
    sid    = "AllowEC2Provisioning"
    effect = "Allow"

    actions = [
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateTags",
      "ec2:RunInstances"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowEC2Termination"
    effect = "Allow"

    actions = [
      "ec2:DeleteLaunchTemplate",
      "ec2:TerminateInstances"
    ]

    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"

      values = [
        "*"
      ]
    }
  }

  statement {
    sid    = "AllowPassingKarpenterNodeRole"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      aws_iam_role.karpenter_node.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "ec2.amazonaws.com"
      ]
    }
  }

  statement {
    sid    = "AllowInterruptionQueueActions"
    effect = "Allow"

    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage"
    ]

    resources = [
      aws_sqs_queue.karpenter_interruption.arn
    ]
  }
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "${var.project_name}-karpenter-controller-policy"
  description = "IAM policy for Karpenter controller"
  policy      = data.aws_iam_policy_document.karpenter_controller.json

  tags = {
    Name = "${var.project_name}-karpenter-controller-policy"
  }
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# ------------------------------------------------------------
# Karpenter discovery tag
# - EC2NodeClass가 subnet/security group을 tag로 찾게 함
# ------------------------------------------------------------

resource "aws_ec2_tag" "karpenter_private_subnet_discovery" {
  for_each = {
    for index, subnet in aws_subnet.private :
    index => subnet.id
  }

  resource_id = each.value
  key         = local.karpenter_discovery_tag_key
  value       = aws_eks_cluster.main.name
}

resource "aws_ec2_tag" "karpenter_cluster_security_group_discovery" {
  resource_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  key         = local.karpenter_discovery_tag_key
  value       = aws_eks_cluster.main.name
}

# ------------------------------------------------------------
# Karpenter Helm Release
# ------------------------------------------------------------

resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_version
  namespace        = var.karpenter_namespace
  create_namespace = false
  wait             = true

  set = [
    {
      name  = "settings.clusterName"
      value = aws_eks_cluster.main.name
    },
    {
      name  = "settings.interruptionQueue"
      value = aws_sqs_queue.karpenter_interruption.name
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.karpenter_controller.arn
    },
    {
      name  = "controller.resources.requests.cpu"
      value = "1"
    },
    {
      name  = "controller.resources.requests.memory"
      value = "1Gi"
    },
    {
      name  = "controller.resources.limits.cpu"
      value = "1"
    },
    {
      name  = "controller.resources.limits.memory"
      value = "1Gi"
    }
  ]

  depends_on = [
    aws_eks_node_group.default,
    aws_iam_role_policy_attachment.karpenter_controller,
    aws_eks_access_entry.karpenter_node,
    aws_ec2_tag.karpenter_private_subnet_discovery,
    aws_ec2_tag.karpenter_cluster_security_group_discovery
  ]
}
