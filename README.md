# pistachio on GitHub Actions

A demo of [pistachio](https://github.com/winebarrel/pistachio) running in CI: a pull
request shows the schema diff, merging it applies the diff to a real PostgreSQL
database.

The jobs run on [CodeBuild-hosted GitHub Actions runners](https://docs.aws.amazon.com/codebuild/latest/userguide/action-runner.html)
rather than GitHub-hosted ones, so they sit inside a VPC and can reach an RDS
instance in its private subnets.

## How it works

The schema lives at the repository root as one SQL file per object, the layout
`pista dump --split` writes.

```
users.sql  posts.sql  comments.sql  tags.sql  post_tags.sql  ...
post_status.sql  social_links.sql  email_address.sql  post_ref_seq.sql
set_updated_at.sql  notify_comment.sql  slugify.sql  ...
```

Each table's indexes, foreign keys, triggers, RLS policies and comments live in
that table's file.

`.github/workflows/pistachio.yml` then does this:

| Event | What runs | Where the output goes |
| --- | --- | --- |
| Pull request to `main` | `pista plan` | A comment on the pull request, via [lastcmt](https://github.com/winebarrel/lastcmt), which minimizes its own earlier comments |
| Push to `main` | `pista apply` | A comment on the pull request the merge commit came from, via `gh pr comment` |

Both read `PISTA_CONN_STR` and `PISTA_PASSWORD` from the CodeBuild project rather
than from GitHub secrets. `PISTA_MANAGE_ROUTINE` is set in the workflow so that
functions and procedures are managed too; without it the triggers in
`comments.sql` would point at functions nobody owns.

## The runner

A queued workflow job fires a `WORKFLOW_JOB_QUEUED` webhook, CodeBuild starts one
build for it, and that build registers itself as an ephemeral runner. The job
picks it up by label:

```yaml
runs-on: codebuild-gha-runner-${{ github.run_id }}-${{ github.run_attempt }}
```

The name after `codebuild-` is the CodeBuild project name, and it has to match
exactly. When it does not, the job waits for a runner forever without failing.

A job runs with the CodeBuild service role already assumed, so it can call AWS
without OIDC or `aws-actions/configure-aws-credentials`. The flip side is that
whatever a workflow runs has that role's permissions.

## Infrastructure

Terraform lives in `terraform/`. It has no variables; edit the values in place.

| File | Contents |
| --- | --- |
| `terraform.tf` | Provider and version constraints. Region is `ap-northeast-1` |
| `vpc.tf` | Data sources for the pre-existing `sandbox` VPC |
| `codebuild.tf` | CodeConnections connection, source credential, project, webhook, log group |
| `rds.tf` | PostgreSQL instance, subnet group, security groups |
| `iam.tf` | The runner's service role |
| `outputs.tf` | The `runs-on` label, connection status, and so on |

Two things are deliberately outside it:

- **The NAT gateway** the private subnets route through was created by hand.
  Putting the project in the VPC sends all of its traffic through the VPC,
  GitHub included, so without a working NAT route the runner cannot register.
- **The GitHub App authorization.** `aws_codeconnections_connection` is created
  in `PENDING` state and only the console can finish the OAuth handshake.

### Bringing it up from scratch

```sh
cd terraform
terraform init
terraform apply -target aws_codeconnections_connection.github
```

Then open [Developer Tools > Settings > Connections](https://ap-northeast-1.console.aws.amazon.com/codesuite/settings/connections?region=ap-northeast-1),
select the connection and choose **Update pending connection**. You will
authorize the AWS Connector for GitHub, choose the account to install it into,
and choose which repositories it can see.

Install it into an organization rather than a personal account if you can. The
connection then depends on the installation instead of on whoever clicked
through, and it is an installation-token connection, which matters here: a
user-token connection invalidates its own token when two builds refresh it at
once, and this runner starts one build per job.

```sh
terraform output connection_status   # must be AVAILABLE
terraform apply
```

## Gotchas

- A connection left `PENDING` fails with `Failed to get access token from <arn>`
  or `Authentication required for primary source.`
- If the repository is outside what the GitHub App installation can see, webhook
  creation fails with `Repository not found or permission denied.`
- Without the Webhooks permission on the app, it fails with
  `Unable to create webhook at this time.` Approve the updated permissions on
  the GitHub side.
- `aws_codebuild_source_credential` is one per account, region and server type.
  If the region already has a GitHub credential, drop the resource and use it.
- A Terraform-managed `aws_security_group` has no egress rule unless you declare
  one, and a runner with no egress reaches neither GitHub nor RDS.
