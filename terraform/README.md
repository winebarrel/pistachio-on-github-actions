# CodeBuild hosted GitHub Actions runner

AWS CodeBuild をこのリポジトリの GitHub Actions セルフホストランナーとして使うための Terraform。
GitHub への接続は PAT ではなく **GitHub App (AWS CodeConnections)** を使っている。

リポジトリに `workflow_job` (queued) の Webhook が張られていて、ジョブがキューイングされる
たびに CodeBuild のビルドが 1 本立ち上がり、GitHub Actions のランナーとして振る舞う
(ジョブごとに使い捨て)。

## 構成

| ファイル | 内容 |
| --- | --- |
| `main.tf` | CodeConnections 接続 / ソース認証情報 / CodeBuild プロジェクト / Webhook / ロググループ |
| `iam.tf` | CodeBuild サービスロール |
| `outputs.tf` | `runs-on` に書くラベルなど |
| `../.github/workflows/hello.yml` | 動作確認用のワークフロー (手動実行) |

以下は直書きなので、変えたければ該当箇所を直接編集する。

| 設定 | 値 | 場所 |
| --- | --- | --- |
| リージョン | `ap-northeast-1` | `terraform.tf` |
| プロジェクト名 | `gha-runner` | `main.tf`, `iam.tf` |
| 対象リポジトリ | `winebarrel/pistachio-on-github-actions` | `main.tf` の `source.location` |
| イメージ | `aws/codebuild/standard:8.0` (Ubuntu) / `BUILD_GENERAL1_SMALL` | `main.tf` |

## 使い方

ワークフローの `runs-on` にこのラベルを書く。

```yaml
runs-on: codebuild-gha-runner-${{ github.run_id }}-${{ github.run_attempt }}
```

`codebuild-` に続くのは CodeBuild のプロジェクト名。`terraform output runs_on_label` でも出せる。

ジョブの中では **CodeBuild のサービスロール (`gha-runner-codebuild`) をそのまま assume した状態**に
なっている。`aws-actions/configure-aws-credentials` や OIDC なしで AWS を叩ける代わりに、
ワークフローに書いた任意のコードがこのロールの権限で動くので、権限を広げるときは注意する。

## ゼロから作り直す場合

apply の途中で 1 回だけ手作業が入る。`aws_codeconnections_connection` は作成した時点では
`PENDING` で、GitHub App (AWS Connector for GitHub) のインストールと認可はコンソールでしかできない。

1. `terraform apply -target aws_codeconnections_connection.github` で接続だけ作る
2. [Developer Tools > Settings > Connections](https://ap-northeast-1.console.aws.amazon.com/codesuite/settings/connections?region=ap-northeast-1)
   で接続を選び **Update pending connection**
   - GitHub の認可 → **インストール先アカウントの選択** → リポジトリの選択、と進む
   - インストール先は個人アカウントではなく Organization を選ぶと、設定した個人に紐付かない
     (インストールベースの IAT 接続になる)
3. `terraform output connection_status` が `AVAILABLE` になったことを確認
4. `terraform apply` で残りを作る

## ハマりどころ

- 接続が `PENDING` のままだと `Failed to get access token from <arn>` /
  `Authentication required for primary source.` でビルドが落ちる。
- `source.location` のリポジトリが存在しない、または GitHub App のインストール範囲
  (Selected repositories) に入っていないと、webhook 作成が
  `Repository not found or permission denied.` で失敗する。
- GitHub App に **Webhooks の権限**を与え忘れると
  `Unable to create webhook at this time.` になる。GitHub 側でアプリの権限更新を承認する。
- `aws_codebuild_source_credential` は **アカウント + リージョン + サーバータイプごとに 1 つ**しか
  持てない。同じリージョンで既に GitHub の認証情報を登録済みなら、
  このリソースを削除して既存のものを使う。
- `runs-on` のプロジェクト名が一致していないと、**エラーにならずジョブが永久にキューに残る**。
- UAT ベースの接続にしてしまうと、並列ビルドでトークンが無効化され合う。
  Actions ランナーはジョブごとにビルドが立つので並列が常態。インストールを選んで IAT にすること。
- Webhook は CodeBuild が GitHub 側に自動で作る。手で消すと動かなくなる。
- CodeConnections は CodeBuild より対応リージョンが少ない。クロスリージョン参照は可能。

## 変更の余地

- ラベル末尾でジョブごとに上書きできる:
  `image:arm-3.0` / `instance-size:small` / `fleet:myFleet` / `buildspec-override:true`
- Lambda コンピューティング (`BUILD_LAMBDA_1GB` + `LINUX_LAMBDA_CONTAINER`) は速い。
  hello world で実測したところ、ジョブ実行時間が 21 秒 → 10 秒になった
  (キュー投入からジョブ開始までは 25 秒 → 29 秒で、ここは変わらない)。
  ワークスペースは `/tmp` 配下に置かれるので、`/tmp` 以外に書けない制約は実質問題にならず、
  ファイル書き込みも JavaScript action も普通に動く。
  ただし 15 分上限 / Docker 不可 / キャッシュ不可 / VPC 不可 / root 権限が要るツール不可。
  イメージは runtime 別のものしかなく (nodejs, python, corretto, go, ruby, dotnet)、plain は無い。
- ARM にする場合は `type = "ARM_CONTAINER"` +
  `aws/codebuild/amazonlinux-aarch64-standard:4.0`。ARM の curated イメージは
  Amazon Linux のみで Ubuntu 版が無いため、`standard:8.0` とは両立しない。
- ウォームプールが欲しければ Reserved capacity fleet (`aws_codebuild_fleet`) を作って
  `environment.fleet` で紐付ける。
