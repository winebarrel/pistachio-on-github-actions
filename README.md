# pistachio on GitHub Actions

[![pistachio](https://github.com/winebarrel/pistachio-on-github-actions/actions/workflows/pistachio.yml/badge.svg)](https://github.com/winebarrel/pistachio-on-github-actions/actions/workflows/pistachio.yml)

A demo of [pistachio](https://github.com/winebarrel/pistachio) running in CI: a pull
request shows the schema diff, merging it applies the diff to a real PostgreSQL
database.

The jobs run on [CodeBuild-hosted GitHub Actions runners](https://docs.aws.amazon.com/codebuild/latest/userguide/action-runner.html)
rather than GitHub-hosted ones, so they sit inside a VPC and can reach an RDS
instance in its private subnets.

## How it works

The schema lives in `tables/`, one SQL file per object. Data migrations live in
`data/`, one timestamped file each.

```
tables/
  users.sql  posts.sql  comments.sql  tags.sql  post_tags.sql  ...
  post_status.sql  social_links.sql  email_address.sql  post_ref_seq.sql
  set_updated_at.sql  notify_comment.sql  slugify.sql  ...
data/
  20260920071958_initial_data.sql
```

Each table's indexes, foreign keys, triggers, RLS policies and comments live in
that table's file.

`.github/workflows/pistachio.yml` then does this:

| Event | What runs | Where the output goes |
| --- | --- | --- |
| Pull request to `main` | `pista plan`, then `qrev plan` | Two comments on the pull request, via [lastcmt](https://github.com/winebarrel/lastcmt) under separate keys so each one only minimizes its own earlier posts |
| Push to `main` | `pista apply`, then `qrev apply` | One comment on the pull request the merge commit came from, via `gh pr comment` |

[qrev](https://github.com/winebarrel/qrev) keeps a history table of the files it
has run, so a data migration is applied once and skipped on every run after
that. It runs after pistachio, since the data depends on the schema.

Both read their connection settings from the CodeBuild project rather than from
GitHub secrets: `PISTA_CONN_STR` and `PISTA_PASSWORD` for pistachio, `QREV_DSN`
and `PGPASSWORD` for qrev. qrev takes a single DSN and has no separate password
option, so the password reaches it through `PGPASSWORD`, which pgx falls back to
for whatever the DSN leaves out. That way it stays in Secrets Manager instead of
being baked into a connection string.

`PISTA_MANAGE_ROUTINE` is set in the workflow so that functions and procedures
are managed too; without it the triggers in `comments.sql` would point at
functions nobody owns.

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
