# sandbox-terraform
個人的にAWS環境の検証などを行うTerraformコードです。

## ローカル環境
```
Terraform: v0.14.7
```

## Teraform環境

### ecs-fargate-vpc-endpoint

以下環境でECS Fargateタスクを起動する検証環境
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
