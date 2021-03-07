# ecs-fargate-vpc-endpoint

以下環境でECS Fargateタスクを起動する検証環境です。

* PlatformVersion = 1.4.0
* インターネットアウトバウンドがないサブネットでタスク起動
* サブネットに以下のVPC Endpointを設定
  - s3 (gateway)
  - ecr.dkr (interface)
  - ecr.api (interface)
  - logs (interface)
  - ssm (interface)
  - secretsmanager (interface)
* タスク定義のSecretsに以下の参照を設定
  - ParameterStore の SecureString
  - SecretsManager

## 構築
1. TerraformにてAWSリソースを構築
2. ECRリポジトリへDockerイメージをプッシュ
3. タスク起動

## 1. TerraformにてAWSリソースを構築
初期化を実行後、デプロイを実行します。

初期化
```
terraform init
```

デプロイ
```
terraform apply
```

## 2. ECRリポジトリへDockerイメージをプッシュ
alpineイメージをそのままECRリポジトリにプッシュします。

アカウントIDは置き換えてください。

```
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com

docker pull alpine:3.12
docker tag alpine:3.12 <ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-fargate-vpc-endpoint-default-alpine:3.12
docker push <ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-fargate-vpc-endpoint-default-alpine:3.12
```

## 3. タスク起動

ECSタスクを構築したサブネットにて起動します。

サブネットID、セキュリティグループID、タスク定義のリビジョンは置き換えてください。

起動するプラットフォームバージョンもここで指定可能です。

```
aws ecs run-task \
  --cluster ecs-fargate-vpc-endpoint-default \
  --count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[<SUBNET_ID>],securityGroups=[<SECURITY_GROUP_ID>],assignPublicIp=DISABLED}" \
  --platform-version 1.4.0 \
  --task-definition ecs-fargate-vpc-endpoint-default:<REVISION>
```
