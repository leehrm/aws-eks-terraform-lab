# SecretOps Phase 1 설계

분석 결과, Phase 1은 "Secret container와 값의 lifecycle 분리"가 핵심입니다. Secret container는 `persistent`, ESO IAM role과 IAM policy는 `cluster`, ESO Helm Application과 Kubernetes 리소스는 `gitops-argocd`에서 관리합니다. 실제 Secret 값은 Terraform이 전혀 읽거나 쓰지 않도록 설계합니다.

## 1. 재사용 가능한 OIDC/IRSA 구성

`cluster/ebs-csi.tf`의 다음 리소스를 그대로 재사용할 수 있습니다.

- `data.tls_certificate.eks_oidc`
- `aws_iam_openid_connect_provider.eks`
- OIDC URL에서 `https://`를 제거해 trust condition key를 만드는 패턴
- `sts:AssumeRoleWithWebIdentity`
- `sub`와 `aud`를 모두 `StringEquals`로 제한하는 방식

ESO용 OIDC provider를 새로 만들면 안 됩니다. 기존 provider를 principal로 참조하고 ESO 전용 IAM role만 추가합니다.

## 2. Terraform 리소스와 파일 구성

`persistent/`:

- 새 파일: `persistent/secrets-manager.tf`
- `aws_secretsmanager_secret` 4개
- 삭제 보호를 위한 `lifecycle.prevent_destroy`
- 삭제를 명시적으로 허용할 경우를 대비한 `recovery_window_in_days = 30`
- `variables.tf`: 환경명 등 비민감 변수
- `outputs.tf`: Secret 이름과 ARN map

`cluster/`:

- 새 파일: `cluster/external-secrets.tf`
- `data.aws_iam_policy_document.eso_assume_role`
- `data.aws_iam_policy_document.eso_secrets_read`
- `aws_iam_role.eso`
- `aws_iam_policy.eso_secrets_read`
- `aws_iam_role_policy_attachment.eso`
- `variables.tf`: persistent secret ARN map 등 비민감 IAM 입력
- `outputs.tf`: ESO role ARN

`gitops-argocd`:

- ESO Helm Application
- `external-secrets` namespace
- ESO ServiceAccount와 `eks.amazonaws.com/role-arn` annotation
- `ClusterSecretStore`
- `ExternalSecret`과 workload 대상 Kubernetes Secret

Terraform은 ServiceAccount나 Kubernetes Secret을 만들지 않아 GitOps ownership과 충돌하지 않습니다.

## 3. Secret container 이름

환경 경계를 이름에 포함하는 구성을 권장합니다.

- `/aws-eks-terraform-lab/dev/task-api/database`
- `/aws-eks-terraform-lab/dev/redis/auth`
- `/aws-eks-terraform-lab/dev/observability/grafana`
- `/aws-eks-terraform-lab/dev/observability/slack`

`prod` 추가 시 동일한 구조에서 `dev`만 `prod`로 바꿉니다. Secret 이름과 tag에는 민감정보를 넣지 않습니다.

Database container에는 RDS master 계정보다 별도의 application DB user를 저장하는 편이 안전합니다.

## 4. 실제 값을 Terraform state에 넣지 않는 방식

Terraform은 `aws_secretsmanager_secret`만 생성하고 다음은 만들지 않습니다.

- `aws_secretsmanager_secret_version`
- Secret 값을 받는 Terraform variable
- `data.aws_secretsmanager_secret_version`
- `random_password`
- Secret value output

실제 값은 권한이 제한된 별도 운영 절차나 CI에서 Secrets Manager에 직접 입력합니다. Terraform은 container metadata와 ARN만 관리합니다.

중요한 제약이 있습니다. 현재 `cluster/rds.tf`은 `aws_db_instance.password`를 사용하므로 RDS master password는 현재 cluster state에 남습니다. Phase 1의 새 Secret에는 값을 넣지 않을 수 있지만, 기존 state의 master password 문제까지 자동으로 해결되지는 않습니다.

RDS의 `manage_master_user_password`가 일반적으로 좋은 대안이지만, AWS 문서상 Secrets Manager-managed master password는 현재 PostgreSQL read replica 구성과 호환성 제한이 있습니다. 현재 저장소에는 read replica가 있으므로 별도 검증 없이 전환하면 안 됩니다. [AWS RDS password management 문서](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html)

권장 방향은 Phase 1에서 RDS를 건드리지 않고, 별도 application DB user를 생성하여 해당 credential만 container에 입력하는 것입니다.

## 5. ESO controller 최소 IAM policy

고정된 Secret ARN만 허용합니다.

- `secretsmanager:GetSecretValue`
- `secretsmanager:DescribeSecret`
- Resource: persistent output으로 전달된 정확한 Secret ARN 4개

제외할 권한:

- `ListSecrets`
- `BatchGetSecretValue`
- `CreateSecret`
- `PutSecretValue`
- `UpdateSecret`
- `DeleteSecret`
- wildcard `Resource = "*"`

AWS-managed `aws/secretsmanager` KMS key를 사용하면 별도 `kms:Decrypt` 부여가 일반적으로 필요하지 않습니다. Customer-managed KMS key를 도입하면 해당 key에 한해 `kms:Decrypt`를 추가하고 `kms:ViaService = secretsmanager.ap-northeast-1.amazonaws.com` 조건을 적용합니다. [AWS Secrets Manager IAM 예제](https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_iam-policies.html), [GetSecretValue 권한](https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html)

## 6. ServiceAccount trust policy

권장 기본값:

- Namespace: `external-secrets`
- ServiceAccount: `external-secrets`

Trust policy 조건:

- Federated principal: `aws_iam_openid_connect_provider.eks.arn`
- Action: `sts:AssumeRoleWithWebIdentity`
- `sub`: `system:serviceaccount:external-secrets:external-secrets`
- `aud`: `sts.amazonaws.com`
- 두 조건 모두 `StringEquals`

ServiceAccount annotation:

- `eks.amazonaws.com/role-arn`
- `eks.amazonaws.com/sts-regional-endpoints: "true"`

이 annotation과 ServiceAccount는 `gitops-argocd`의 ESO Helm Application에서 관리합니다. namespace wildcard나 ServiceAccount wildcard는 사용하지 않습니다. [AWS EKS IRSA trust policy](https://docs.aws.amazon.com/eks/latest/userguide/associate-service-account-role.html), [ESO AWS 인증](https://external-secrets.io/latest/provider/aws-access/)

## 7. Terraform output

`persistent` output:

- `secret_container_names`: 이름 map
- `secret_container_arns`: ARN map

`cluster` output:

- `external_secrets_role_arn`

출력하면 안 되는 항목:

- Secret value
- JSON payload
- Secret version 내용
- Kubernetes Secret data

Secret ARN과 이름은 인증정보는 아니지만 인프라 metadata이므로 공개 로그 업로드는 최소화합니다.

## 8. State 배치

- Secret container: `persistent` state
- 기존 EKS OIDC provider: `cluster` state
- ESO IAM role/policy: `cluster` state
- ESO Helm Application, namespace, ServiceAccount annotation, `ClusterSecretStore`, `ExternalSecret`: `gitops-argocd`

`cluster`는 `persistent`의 state 자체를 읽지 않고, `persistent` output의 ARN map을 비민감 입력 변수로 전달받습니다. 이렇게 하면 두 state의 경계를 유지하면서 IAM policy를 정확한 ARN으로 제한할 수 있습니다.

## 9. Cluster destroy 시 보존

- Secret container는 `persistent`에 있으므로 `cluster destroy` 대상이 아닙니다.
- `lifecycle.prevent_destroy = true`로 실수에 의한 persistent destroy도 차단합니다.
- 삭제를 명시적으로 허용할 때도 즉시 삭제 대신 30일 recovery window를 사용합니다.
- cluster destroy 시 ESO IAM role은 삭제되지만 Secret container와 version은 유지됩니다. 재생성 후에는 GitOps가 ESO Helm Application과 Kubernetes 리소스를 다시 적용합니다.
- 재생성된 cluster는 새 OIDC provider와 새 ESO role을 통해 동일한 persistent Secret ARN에 다시 접근합니다.
- Secret에 이전 cluster의 IAM role을 직접 지정하는 resource policy는 가급적 만들지 않아 stale principal 문제를 피합니다.

## 10. 구현 및 검증 순서

1. 현재 provider schema 로드 실패를 먼저 해결하고 두 root의 `terraform validate` baseline을 복구
2. `gitops-argocd`에서 사용할 명시적 ESO chart version과 EKS 1.35 호환성 확인
3. `persistent`에 Secret container만 구현
4. `fmt -check`, `validate`, `git diff --check`
5. 승인된 persistent plan에서 Secret version이나 기존 ECR 변경이 없는지 확인
6. 승인 후 container 생성
7. 제한된 별도 절차로 Secret 값을 입력
8. `cluster`에 ESO IAM role, 최소 policy, output 구현
9. `cluster`에서 `fmt -check`, `validate` 검증
10. 승인된 cluster plan에서 EKS/OIDC/RDS replacement가 없는지 확인
11. `gitops-argocd`에 ESO Helm Application, namespace, ServiceAccount annotation, `ClusterSecretStore`, `ExternalSecret` 추가
12. 한 workload씩 전환하고 ESO status와 target Secret 존재 여부만 검증
13. 기존 Secret 주입 방식을 제거하기 전에 application readiness와 rollback 경로 확인

검증 로그에서는 Secret value나 Kubernetes Secret의 `.data`를 출력하지 않습니다.

## 11. 위험과 rollback

주요 위험:

- ServiceAccount 이름이나 namespace 불일치로 IRSA 실패
- Secrets Manager ARN의 자동 suffix를 고려하지 않은 IAM resource 지정
- Secret container에 version이 없어 ESO reconcile 실패
- Secret JSON property 이름과 `ExternalSecret` mapping 불일치
- ESO controller role 하나에 과도한 Secret 접근 권한 집중
- refresh interval이 너무 짧아 API 비용·throttling 증가
- 기존 Kubernetes Secret을 ESO가 덮어써 workload 장애 발생
- 현재 local Terraform state의 기존 RDS password 노출 위험
- 현재 PostgreSQL read replica 때문에 RDS-managed master password 전환이 제한될 가능성

Rollback 순서:

1. workload를 기존 Secret source로 복귀
2. readiness와 DB/Redis 연결 확인
3. `gitops-argocd`에서 `ExternalSecret`, `ClusterSecretStore`, ESO Helm Application 제거
4. `cluster`에서 ESO IAM role과 IAM policy 제거
5. persistent Secret container는 삭제하지 않고 유지
6. RDS 구성은 Phase 1에서 변경하지 않으므로 DB rollback은 발생하지 않음

Phase 1에서는 RDS password 설정 변경과 ESO 도입을 한 번에 묶지 않는 것이 안전합니다.
