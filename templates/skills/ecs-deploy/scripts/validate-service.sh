#!/usr/bin/env bash
# Acompanha rollout de service ECS — uso: validate-service.sh <cluster> <service>
set -euo pipefail

CLUSTER="${1:?uso: validate-service.sh <cluster> <service>}"
SERVICE="${2:?uso: validate-service.sh <cluster> <service>}"

echo "→ status do service"
aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
  --query 'services[0].{status:status,desired:desiredCount,running:runningCount,pending:pendingCount,taskDef:taskDefinition}' \
  --output table

echo "→ últimos eventos"
aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
  --query 'services[0].events[0:5].[createdAt,message]' --output table

echo "→ aguardando estabilizar (timeout ~10min)"
if aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE"; then
  echo "✓ Service estável"
else
  echo "✗ Service NÃO estabilizou — investigue:"
  echo "  aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE --desired-status STOPPED"
  echo "  aws ecs describe-tasks --cluster $CLUSTER --tasks <arn> --query 'tasks[0].stoppedReason'"
  exit 1
fi

# Target group health (se houver ALB associado)
TG_ARN=$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
  --query 'services[0].loadBalancers[0].targetGroupArn' --output text 2>/dev/null || echo "None")

if [[ "$TG_ARN" != "None" && -n "$TG_ARN" ]]; then
  echo "→ saúde dos targets"
  aws elbv2 describe-target-health --target-group-arn "$TG_ARN" \
    --query 'TargetHealthDescriptions[].{target:Target.Id,port:Target.Port,state:TargetHealth.State,reason:TargetHealth.Reason}' \
    --output table
fi
