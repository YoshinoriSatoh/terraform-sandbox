#!/bin/sh

aws ecs run-task \
  --cluster ecs-fargate-vpc-endpoint-default \
  --count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-07203aef0c30c1076],securityGroups=[sg-05a20c2409383284f],assignPublicIp=DISABLED}" \
  --platform-version 1.4.0 \
  --task-definition ecs-fargate-vpc-endpoint-default:9