# aws-eks-terraform-lab
Terraform으로 AWS 기반 EKS 클러스터를 구성하는 실습 프로젝트.

## 목적
이 프로젝트의 목표는 Terraform을 사용하여 AWS 네트워크 리소스와 EKS 클러스터를 코드로 생성하고, 로컬 환경에서 `kubectl`로 EKS 클러스터에 접속.

## 구성 리소스
현재 Terraform으로 구성한 주요 리소스는 다음과 같음.

- VPC
- Public Subnet
- Private Subnet
- Internet Gateway
- Route Table
- NAT Gateway
- EKS Cluster
- EKS Managed Node Group
- ECR Repository

## 아키텍처 개요
```text
VPC
├── Public Subnet
│   ├── Internet Gateway
│   └── NAT Gateway
│
├── Private Subnet
│   └── EKS Worker Nodes
│
└── EKS Cluster
    └── Managed Node Group

Private Subnet에 배치된 EKS Worker Node는 NAT Gateway를 통해 외부 인터넷으로 outbound 통신을 수행.

## 파일 구조
```text
.
├── versions.tf      # Terraform 및 Provider 버전 정의
├── providers.tf     # AWS Provider 설정
├── variables.tf     # 변수 정의
├── terraform.tfvars # 실제 변수 값, Git에 커밋하지 않음
├── main.tf          # VPC, Subnet, Route Table, NAT Gateway 등 네트워크 리소스
├── iam.tf           # EKS Cluster 및 Node Group IAM Role
├── eks.tf           # EKS Cluster 및 Managed Node Group
├── ecr.tf           # ECR Repository
├── outputs.tf       # 생성된 리소스 출력값
└── README.md
```

## 사용 도구
- Terraform
- AWS CLI
- AWS IAM Identity Center
- Amazon EKS
- kubectl

## 실행 순서
1. AWS 인증 확인
```bash
aws sts get-caller-identity --profile harim
```
2. Terraform 초기화
```bash
terraform init
```
3. Terraform 코드 검증
```bash
terraform fmt -recursive
terraform validate
```
4. 생성 계획 확인
```bash
terraform plan
```
5. 리소스 생성
```bash
terraform apply
```
6. EKS kubeconfig 설정
```bash
aws eks update-kubeconfig \
  --region ap-northeast-1 \
  --name aws-eks-terraform-lab-eks \
  --profile harim
```
7. 클러스터 확인
```bash
harim@DESKTOP-NJOID79:~/aws-eks-terraform-lab$ kubectl get nodes
NAME                                              STATUS   ROLES    AGE     VERSION
ip-10-0-101-230.ap-northeast-1.compute.internal   Ready    <none>   2m47s   v1.30.14-eks-7fcd7ec
ip-10-0-102-233.ap-northeast-1.compute.internal   Ready    <none>   2m47s   v1.30.14-eks-7fcd7ec


harim@DESKTOP-NJOID79:~/aws-eks-terraform-lab$ kubectl get pods -A
NAMESPACE     NAME                       READY   STATUS    RESTARTS   AGE
kube-system   aws-node-n6hlm             2/2     Running   0          2m58s
kube-system   aws-node-wds27             2/2     Running   0          2m58s
kube-system   coredns-5944c65844-66kkl   1/1     Running   0          6m37s
kube-system   coredns-5944c65844-l72qt   1/1     Running   0          6m37s
kube-system   kube-proxy-9sw5f           1/1     Running   0          2m58s
kube-system   kube-proxy-bz52k           1/1     Running   0          2m58s
```
