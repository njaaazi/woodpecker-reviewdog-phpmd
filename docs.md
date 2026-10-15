---
name: Reviewdog PHPMD
description: Run PHP Mess Detector with Reviewdog and report to GitHub
author: Njazi Shehu
tags: [php, phpmd, reviewdog, lint]
containerImage: njaaazi/woodpecker-reviewdog-phpmd
url: https://github.com/njaaazi/woodpecker-reviewdog-phpmd
---

# Overview

Woodpecker CI plugin that runs [PHP Mess Detector](https://phpmd.org) with [Reviewdog](https://github.com/reviewdog/reviewdog) and reports findings to GitHub.

Based on [`mikebronner/action-reviewdog-phpmd`](https://github.com/mikebronner/action-reviewdog-phpmd).

## Images

| Tag | PHP |
| --- | --- |
| `njaaazi/woodpecker-reviewdog-phpmd:8.3` | 8.3 |
| `njaaazi/woodpecker-reviewdog-phpmd:8.4` | 8.4 |
| `njaaazi/woodpecker-reviewdog-phpmd:8.5` | 8.5 |
| `njaaazi/woodpecker-reviewdog-phpmd:latest` | 8.5 |

## Settings

| Settings Name | Default | Description |
| ------------- | ------- | ----------- |
| `github_token` | _none_ | GitHub PAT (`repo` / `public_repo`) or GitHub App installation token. Required unless `reporter` is `local`. |
| `level` | `warning` | Reviewdog report level: `info`, `warning`, `error`. |
| `reporter` | `github-pr-review` | Reviewdog reporter: `github-pr-review`, `github-pr-check`, `github-check`. |
| `standard` | `cleancode,codesize,controversial,design,naming,unusedcode` | PHPMD rulesets or a ruleset file path. |
| `target_directory` | `src` | Directory to scan. |
| `exclude` | _empty_ | Optional PHPMD `--exclude` pattern. |
| `name` | `PHPMD` | Reviewdog check name. |
| `baseline_file` | _empty_ | Optional PHPMD `--baseline-file` path. |
| `fail_on_error` | `false` | If `true`, Reviewdog exits 1 when it finds any issue. |
| `changed_only` | `false` | If `true`, lint only the PHP files the PR changed under `target_directory` (from `CI_PIPELINE_FILES`). Lints everything when that list is empty. |

`github-pr-review` posts inline GitHub PR comments as the token's identity. Use this step on `pull_request` events. `github-check` and `github-pr-check` need an App installation token. Store `github_token` using [Woodpecker secrets](https://woodpecker-ci.org/docs/usage/secrets).

## Examples

```yaml
steps:
  phpmd:
    image: njaaazi/woodpecker-reviewdog-phpmd:8.4
    settings:
      github_token:
        from_secret: github_token
      level: warning
      reporter: github-pr-review
      standard: cleancode,codesize,controversial,design,naming,unusedcode
      target_directory: src
    when:
      event: pull_request
```
