#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TERRAFORM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

TIMEOUT_SECONDS=900
AWS_PROFILE_NAME="${AWS_PROFILE:-harim}"
AWS_REGION_NAME="${AWS_REGION:-ap-northeast-1}"
AUTO_APPROVE=false

usage() {
  cat <<'EOF'
Usage: ./scripts/pre-destroy-cleanup.sh [options]

Clean up Kubernetes and AWS resources that can block terraform destroy.
This script does not run terraform destroy and does not delete RDS resources.

Options:
  --aws-profile PROFILE  AWS CLI profile (default: $AWS_PROFILE or harim)
  --region REGION        AWS region (default: $AWS_REGION or ap-northeast-1)
  --timeout SECONDS      Maximum wait per cleanup phase (default: 900)
  --yes                  Skip the cluster-name confirmation prompt
  -h, --help             Show this help
EOF
}

log() {
  printf '[pre-destroy] %s\n' "$*"
}

die() {
  printf '[pre-destroy] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --aws-profile)
      [[ $# -ge 2 ]] || die "--aws-profile requires a value"
      AWS_PROFILE_NAME="$2"
      shift 2
      ;;
    --region)
      [[ $# -ge 2 ]] || die "--region requires a value"
      AWS_REGION_NAME="$2"
      shift 2
      ;;
    --timeout)
      [[ $# -ge 2 ]] || die "--timeout requires a value"
      TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --yes)
      AUTO_APPROVE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

[[ "${TIMEOUT_SECONDS}" =~ ^[1-9][0-9]*$ ]] || die "--timeout must be a positive integer"

require_command aws
require_command kubectl
require_command terraform

cd "${TERRAFORM_DIR}"

[[ ! -f .terraform.tfstate.lock.info ]] || die \
  "Terraform state is locked. Finish or cancel the active Terraform operation first."

cluster_name="$(terraform output -raw eks_cluster_name 2>/dev/null)" || die \
  "Could not read eks_cluster_name from Terraform state."
vpc_id="$(terraform output -raw vpc_id 2>/dev/null)" || die \
  "Could not read vpc_id from Terraform state."
terraform_account_id="$(terraform output -raw aws_account_id 2>/dev/null)" || die \
  "Could not read aws_account_id from Terraform state."
kube_context="$(kubectl config current-context 2>/dev/null)" || die \
  "No current kubectl context is configured."

case "${kube_context}" in
  *"${cluster_name}"*) ;;
  *) die "kubectl context '${kube_context}' does not match Terraform cluster '${cluster_name}'." ;;
esac

kubectl get namespace kube-system >/dev/null 2>&1 || die \
  "Cannot connect to Kubernetes context '${kube_context}'."
aws_account_id="$(aws --profile "${AWS_PROFILE_NAME}" --region "${AWS_REGION_NAME}" \
  sts get-caller-identity --query Account --output text)" || die "AWS authentication failed."
[[ "${aws_account_id}" == "${terraform_account_id}" ]] || die \
  "AWS account '${aws_account_id}' does not match Terraform account '${terraform_account_id}'."
aws --profile "${AWS_PROFILE_NAME}" --region "${AWS_REGION_NAME}" \
  ec2 describe-vpcs --vpc-ids "${vpc_id}" >/dev/null || die \
  "Terraform VPC '${vpc_id}' was not found with the selected AWS profile and region."

log "Cluster:     ${cluster_name}"
log "Context:     ${kube_context}"
log "VPC:         ${vpc_id}"
log "AWS profile: ${AWS_PROFILE_NAME}"
log "AWS region:  ${AWS_REGION_NAME}"

if terraform state list 2>/dev/null | grep -q '^aws_db_instance\.'; then
  log "WARNING: cluster Terraform state contains RDS instances."
  log "WARNING: a later terraform destroy will delete them without a final snapshot."
fi

if [[ "${AUTO_APPROVE}" != true ]]; then
  printf '\nThis will delete GitOps workloads, load balancers, EBS-backed PVs, and Karpenter nodes.\n'
  printf "Type the cluster name '%s' to continue: " "${cluster_name}"
  read -r confirmation
  [[ "${confirmation}" == "${cluster_name}" ]] || die \
    "Confirmation did not match; no resources were deleted."
fi

# Capture cloud resource IDs before their Kubernetes objects are removed.
ebs_volume_ids="$(kubectl get pv \
  -o jsonpath='{range .items[?(@.spec.csi.driver=="ebs.csi.aws.com")]}{.spec.csi.volumeHandle}{"\n"}{end}' \
  2>/dev/null || true)"
karpenter_instance_ids="$(kubectl get nodeclaims.karpenter.sh \
  -o jsonpath='{range .items[*]}{.status.providerID}{"\n"}{end}' 2>/dev/null \
  | sed -E 's#^.*/##' || true)"

# Discover namespaces from Argo CD and retain known namespaces as a fallback.
application_namespaces="$(kubectl get applications.argoproj.io -n argocd \
  -o jsonpath='{range .items[*]}{.spec.destination.namespace}{"\n"}{end}' 2>/dev/null || true)"
cleanup_namespaces="$(printf '%s\n%s\n' \
  "${application_namespaces}" \
  'argo-task-api cert-manager external-secrets loki monitoring redis traefik' \
  | tr ' ' '\n' \
  | awk 'NF && $0 != "default" && $0 != "kube-system" && $0 != "kube-public" && $0 != "kube-node-lease" && $0 != "argocd"' \
  | sort -u)"
workload_namespaces="$(printf '%s\n' "${cleanup_namespaces}" \
  | awk '$0 != "cert-manager" && $0 != "external-secrets"')"
operator_namespaces="$(printf '%s\n' "${cleanup_namespaces}" \
  | awk '$0 == "cert-manager" || $0 == "external-secrets"')"

delete_and_wait_for_namespaces() {
  local namespaces="$1"
  local namespace

  for namespace in ${namespaces}; do
    if kubectl get namespace "${namespace}" >/dev/null 2>&1; then
      kubectl delete namespace "${namespace}" --wait=false
    fi
  done

  for namespace in ${namespaces}; do
    if kubectl get namespace "${namespace}" >/dev/null 2>&1; then
      log "Waiting for namespace/${namespace} to be deleted"
      kubectl wait --for=delete "namespace/${namespace}" --timeout="${TIMEOUT_SECONDS}s" || die \
        "namespace/${namespace} is still terminating. Inspect its finalizers before continuing."
    fi
  done
}

log "Stopping Argo CD reconciliation"
if kubectl get statefulset argocd-application-controller -n argocd >/dev/null 2>&1; then
  kubectl scale statefulset argocd-application-controller -n argocd --replicas=0
fi
if kubectl get deployment argocd-applicationset-controller -n argocd >/dev/null 2>&1; then
  kubectl scale deployment argocd-applicationset-controller -n argocd --replicas=0
fi

log "Deleting GitOps workload namespaces"
delete_and_wait_for_namespaces "${workload_namespaces}"

log "Deleting operator namespaces after their managed resources are gone"
delete_and_wait_for_namespaces "${operator_namespaces}"

if kubectl api-resources --api-group=karpenter.sh -o name 2>/dev/null \
  | grep -q '^nodepools\.karpenter\.sh$'; then
  log "Deleting Karpenter NodePools and NodeClaims while the controller is still running"
  kubectl delete nodepools.karpenter.sh --all --wait=false --ignore-not-found
  kubectl delete nodeclaims.karpenter.sh --all --wait=false --ignore-not-found

  deadline=$((SECONDS + TIMEOUT_SECONDS))
  while [[ -n "$(kubectl get nodeclaims.karpenter.sh -o name 2>/dev/null || true)" ]]; do
    ((SECONDS < deadline)) || die "Karpenter NodeClaims were not deleted before the timeout."
    sleep 10
  done
fi

log "Waiting for AWS load balancers in ${vpc_id} to be deleted"
deadline=$((SECONDS + TIMEOUT_SECONDS))
while true; do
  classic_lbs="$(aws --profile "${AWS_PROFILE_NAME}" --region "${AWS_REGION_NAME}" \
    elb describe-load-balancers \
    --query "LoadBalancerDescriptions[?VPCId=='${vpc_id}'].LoadBalancerName" \
    --output text)"
  v2_lbs="$(aws --profile "${AWS_PROFILE_NAME}" --region "${AWS_REGION_NAME}" \
    elbv2 describe-load-balancers \
    --query "LoadBalancers[?VpcId=='${vpc_id}'].LoadBalancerName" \
    --output text)"
  [[ -z "${classic_lbs}${v2_lbs}" || "${classic_lbs}${v2_lbs}" == "NoneNone" ]] && break
  ((SECONDS < deadline)) || die "AWS load balancers still exist: ${classic_lbs} ${v2_lbs}"
  sleep 10
done

log "Waiting for load balancer network interfaces in ${vpc_id} to be deleted"
deadline=$((SECONDS + TIMEOUT_SECONDS))
while true; do
  elb_network_interfaces="$(aws --profile "${AWS_PROFILE_NAME}" --region "${AWS_REGION_NAME}" \
    ec2 describe-network-interfaces \
    --filters "Name=vpc-id,Values=${vpc_id}" 'Name=description,Values=ELB*' \
    --query 'NetworkInterfaces[].NetworkInterfaceId' --output text)"
  [[ -z "${elb_network_interfaces}" || "${elb_network_interfaces}" == "None" ]] && break
  ((SECONDS < deadline)) || die \
    "Load balancer network interfaces still exist: ${elb_network_interfaces}"
  sleep 10
done

for volume_id in ${ebs_volume_ids}; do
  log "Waiting for EBS volume ${volume_id} to be deleted"
  deadline=$((SECONDS + TIMEOUT_SECONDS))
  while true; do
    if ! volume_state="$(aws --profile "${AWS_PROFILE_NAME}" --region "${AWS_REGION_NAME}" \
      ec2 describe-volumes --volume-ids "${volume_id}" \
      --query 'Volumes[0].State' --output text 2>&1)"; then
      [[ "${volume_state}" == *"InvalidVolume.NotFound"* ]] && break
      die "Failed to check EBS volume ${volume_id}: ${volume_state}"
    fi
    [[ -z "${volume_state}" || "${volume_state}" == "None" ]] && break
    ((SECONDS < deadline)) || die "EBS volume ${volume_id} still exists in state ${volume_state}."
    sleep 10
  done
done

for instance_id in ${karpenter_instance_ids}; do
  [[ -n "${instance_id}" ]] || continue
  log "Waiting for Karpenter EC2 instance ${instance_id} to terminate"
  deadline=$((SECONDS + TIMEOUT_SECONDS))
  while true; do
    if ! instance_state="$(aws --profile "${AWS_PROFILE_NAME}" --region "${AWS_REGION_NAME}" \
      ec2 describe-instances --instance-ids "${instance_id}" \
      --query 'Reservations[].Instances[].State.Name' --output text 2>&1)"; then
      [[ "${instance_state}" == *"InvalidInstanceID.NotFound"* ]] && break
      die "Failed to check EC2 instance ${instance_id}: ${instance_state}"
    fi
    [[ -z "${instance_state}" || "${instance_state}" == "None" || "${instance_state}" == "terminated" ]] && break
    ((SECONDS < deadline)) || die "EC2 instance ${instance_id} is still ${instance_state}."
    sleep 10
  done
done

remaining_lb_services="$(kubectl get services -A \
  -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' \
  2>/dev/null || true)"
remaining_ebs_pvs="$(kubectl get pv \
  -o jsonpath='{range .items[?(@.spec.csi.driver=="ebs.csi.aws.com")]}{.metadata.name}{"\n"}{end}' \
  2>/dev/null || true)"
remaining_nodeclaims="$(kubectl get nodeclaims.karpenter.sh -o name 2>/dev/null || true)"

[[ -z "${remaining_lb_services}" ]] || die "LoadBalancer Services remain: ${remaining_lb_services}"
[[ -z "${remaining_ebs_pvs}" ]] || die "EBS-backed PVs remain: ${remaining_ebs_pvs}"
[[ -z "${remaining_nodeclaims}" ]] || die "Karpenter NodeClaims remain: ${remaining_nodeclaims}"

log "Pre-destroy cleanup completed successfully."
log "Review the destroy plan next:"
printf '\n  cd %q\n  terraform plan -destroy\n  terraform destroy\n\n' "${TERRAFORM_DIR}"
