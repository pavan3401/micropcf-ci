#!/bin/bash

set -e

echo "$BOSH_PRIVATE_KEY" > bosh.pem

set -x

STACK_INFO=$(aws cloudformation describe-stacks --stack-name "$CLOUDFORMATION_STACK_NAME")

function get_stack_output() {
  echo "$STACK_INFO" | jq -r "[ .Stacks[0].Outputs[] | { (.OutputKey): .OutputValue } | .$1 ] | add"
}

ELASTIC_IP=$(get_stack_output MicroEIP)
SUBNET_ID=$(get_stack_output BOSHSubnetID)
AVAILABILITY_ZONE=$(get_stack_output AvailabilityZone)
SECURITY_GROUP_ID=$(get_stack_output BOSHSecurityGroupID)
SECURITY_GROUP_NAME=$(aws ec2 describe-security-groups --group-ids=$SECURITY_GROUP_ID | jq -r .SecurityGroups[0].GroupName)

cp micropcf-ci/tasks/deploy-bosh/manifest.yml .

sed -i "s/AVAILABILITY-ZONE/$AVAILABILITY_ZONE/g" manifest.yml
sed -i "s/ELASTIC-IP/$ELASTIC_IP/g" manifest.yml
sed -i "s/ACCESS-KEY-ID/$AWS_ACCESS_KEY_ID/g" manifest.yml
sed -i "s/SECRET-ACCESS-KEY/$AWS_SECRET_ACCESS_KEY/g" manifest.yml
sed -i "s/SUBNET-ID/$SUBNET_ID/g" manifest.yml
sed -i "s/SECURITY-GROUP-NAME/$SECURITY_GROUP_NAME/g" manifest.yml

bosh-init deploy manifest.yml
