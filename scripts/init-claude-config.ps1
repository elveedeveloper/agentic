<#
.SYNOPSIS
    Bootstrap a consumer repo with the Agentic agentic-dev config.

.DESCRIPTION
    Initializes a target repo so it consumes the shared Agentic config:
      - Drops in CLAUDE.md (from templates/<stack>/CLAUDE.md, placeholders intact for human edit).
      - Drops in .claude/ (settings.json + hooks).
      - Generates a thin .github/workflows/ci.yml that calls Agentic's reusable workflow over the network.
      - Optionally generates Tier-2 workflow files (review, pr-bot) that also call Agentic's reusable variants.

    File copies are skipped if the destination already exists, unless -Force is passed.
    This is the lightweight sharing pattern: each consumer ends up with local copies of hooks/CLAUDE.md
    (so they work offline), and reusable workflows over the network for CI. To pull updates after the
    Agentic templates change, re-run this script with -Force on the affected paths.

.PARAMETER Target
    Absolute path to the consumer repo's root.

.PARAMETER Stack
    Which template to use: node | dotnet | nextjs.

.PARAMETER AgenticOwner
    GitHub owner of the Agentic repo. Used in the generated workflow `uses:` reference.

.PARAMETER AgenticRepo
    GitHub repo name of the Agentic repo. Used in the generated workflow `uses:` reference.

.PARAMETER AgenticRef
    Git ref to pin the reusable workflows to. 'main' tracks latest (easy, risky); a tag like 'v1' is safer.

.PARAMETER WithTier2
    Also generate claude-review.yml and claude-pr-bot.yml workflow shims in the consumer.

.PARAMETER Force
    Overwrite existing destination files. Use with care -- this can clobber per-repo CLAUDE.md edits.

.EXAMPLE
    .\scripts\init-claude-config.ps1 `
        -Target d:\Elvee\repository\calculator-api `
        -Stack dotnet `
        -AgenticOwner elveedeveloper `
        -AgenticRepo agentic `
        -AgenticRef main

.EXAMPLE
    .\scripts\init-claude-config.ps1 -Target d:\Elvee\repository\calculator-api -Stack dotnet -WithTier2 -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Target,

    [Parameter(Mandatory = $true)]
    [ValidateSet('node', 'dotnet', 'nextjs')]
    [string]$Stack,

    [string]$AgenticOwner = 'elveedeveloper',
    [string]$AgenticRepo  = 'agentic',
    [string]$AgenticRef   = 'main',
    [switch]$WithTier2,
    [switch]$WithFromJira,
    [switch]$WithJiraSync,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Resolve the Agentic repo root (this script lives at <root>/scripts/).
$AgenticRoot   = Split-Path -Parent $PSScriptRoot
$TemplateRoot  = Join-Path $AgenticRoot "templates\$Stack"

if (-not (Test-Path $TemplateRoot)) {
    throw "Template not found: $TemplateRoot. Is -Stack correct, and is this script being run from a checkout of the Agentic repo?"
}
if (-not (Test-Path $Target)) {
    throw "Target does not exist: $Target. Create the consumer repo first (git init / gh repo clone), then re-run."
}
if (-not (Test-Path (Join-Path $Target '.git'))) {
    Write-Warning "$Target is not a git repo. The bootstrap will still write files, but consider 'git init' first."
}

function Copy-OrSkip {
    param([string]$Source, [string]$Destination)

    if ((Test-Path $Destination) -and -not $Force) {
        Write-Host "  [skip]  $Destination (already exists; pass -Force to overwrite)"
        return
    }

    $destDir = Split-Path -Parent $Destination
    if ($destDir -and -not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }

    if (Test-Path $Source -PathType Container) {
        Copy-Item -Path $Source -Destination $Destination -Recurse -Force
    } else {
        Copy-Item -Path $Source -Destination $Destination -Force
    }
    Write-Host "  [copy]  $Destination"
}

function Write-FileOrSkip {
    param([string]$Destination, [string]$Content)

    if ((Test-Path $Destination) -and -not $Force) {
        Write-Host "  [skip]  $Destination (already exists; pass -Force to overwrite)"
        return
    }

    $destDir = Split-Path -Parent $Destination
    if ($destDir -and -not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }

    Set-Content -Path $Destination -Value $Content -Encoding utf8 -NoNewline:$false
    Write-Host "  [write] $Destination"
}

Write-Host ""
Write-Host "Initializing Agentic config in $Target (stack: $Stack)" -ForegroundColor Cyan
Write-Host "  Source : $TemplateRoot"
Write-Host "  Pinned : ${AgenticOwner}/${AgenticRepo}@${AgenticRef}"
Write-Host ""

# 1. Drop CLAUDE.md (placeholders intact -- human edits these after init).
Copy-OrSkip -Source (Join-Path $TemplateRoot 'CLAUDE.md') `
            -Destination (Join-Path $Target 'CLAUDE.md')

# 2. Drop .claude/ (settings + hooks).
Copy-OrSkip -Source (Join-Path $TemplateRoot '.claude') `
            -Destination (Join-Path $Target '.claude')

# 3. Generate thin ci.yml that calls the reusable workflow.
$ciDestination = Join-Path $Target '.github\workflows\ci.yml'

switch ($Stack) {
    'dotnet' {
        $reusableName = 'reusable-ci-dotnet.yml'
        $usesLine     = "uses: ${AgenticOwner}/${AgenticRepo}/.github/workflows/${reusableName}@${AgenticRef}"
        $ciContent = @"
name: ci

# This workflow is generated by Agentic's init-claude-config.ps1.
# All actual CI logic lives in the reusable workflow at:
#   ${AgenticOwner}/${AgenticRepo}/.github/workflows/${reusableName}@${AgenticRef}
# Re-run init-claude-config.ps1 -Force to regenerate this file when the
# pattern changes in Agentic.

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ci-`${{ github.workflow }}-`${{ github.ref }}
  cancel-in-progress: true

jobs:
  check:
    ${usesLine}
    with:
      dotnet-version: '8.0.x'
"@
    }
    'node' {
        $reusableName = 'reusable-ci-node.yml'
        $usesLine     = "uses: ${AgenticOwner}/${AgenticRepo}/.github/workflows/${reusableName}@${AgenticRef}"
        $ciContent = @"
name: ci

# This workflow is generated by Agentic's init-claude-config.ps1.
# All actual CI logic lives in the reusable workflow at:
#   ${AgenticOwner}/${AgenticRepo}/.github/workflows/${reusableName}@${AgenticRef}
# Re-run init-claude-config.ps1 -Force to regenerate this file when the
# pattern changes in Agentic.

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ci-`${{ github.workflow }}-`${{ github.ref }}
  cancel-in-progress: true

jobs:
  check:
    ${usesLine}
    with:
      node-version: '22.x'
"@
    }
    'nextjs' {
        Write-Warning "Next.js reusable workflow is not yet implemented in Agentic. Skipping ci.yml generation. See docs/consumer-setup.md for manual setup."
        $ciContent = $null
    }
}

if ($ciContent) {
    Write-FileOrSkip -Destination $ciDestination -Content $ciContent
}

# 4. Optional Tier-2 shims.
if ($WithTier2 -and $Stack -eq 'dotnet') {
    $reviewContent = @"
name: claude-review

# Tier-2 auto-review. Delegates to Agentic's reusable workflow.
on:
  pull_request:
    types: [opened, synchronize, ready_for_review]

permissions:
  contents: read
  pull-requests: write

concurrency:
  group: claude-review-`${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  review:
    if: `${{ !github.event.pull_request.draft }}
    uses: ${AgenticOwner}/${AgenticRepo}/.github/workflows/reusable-claude-review.yml@${AgenticRef}
    secrets:
      anthropic-api-key: `${{ secrets.ANTHROPIC_API_KEY }}
"@

    $prBotContent = @"
name: claude-pr-bot

# Tier-2 @claude PR bot. Delegates to Agentic's reusable workflow.
on:
  issue_comment:
    types: [created]

permissions:
  contents: write
  pull-requests: write
  issues: write

jobs:
  respond:
    if: `${{ github.event.issue.pull_request && contains(github.event.comment.body, '@claude') }}
    uses: ${AgenticOwner}/${AgenticRepo}/.github/workflows/reusable-claude-pr-bot.yml@${AgenticRef}
    secrets:
      anthropic-api-key: `${{ secrets.ANTHROPIC_API_KEY }}
      pr-bot-token:     `${{ secrets.PR_BOT_TOKEN }}
"@

    Write-FileOrSkip -Destination (Join-Path $Target '.github\workflows\claude-review.yml')  -Content $reviewContent
    Write-FileOrSkip -Destination (Join-Path $Target '.github\workflows\claude-pr-bot.yml') -Content $prBotContent
}
elseif ($WithTier2) {
    Write-Warning "Tier-2 reusable workflows (claude-review, claude-pr-bot) are only implemented for the 'dotnet' stack so far."
}

# 5. Optional Tier-2 autonomous: Jira label -> draft PR (claude-from-jira).
if ($WithFromJira -and $Stack -eq 'node') {
    $fromJiraContent = @"
name: claude-from-jira

# Tier-2 autonomous: when a Jira ticket is labeled 'agent-ready', a
# Jira automation rule fires a repository_dispatch here, and Claude
# develops the ticket end-to-end into a DRAFT PR.
# Required repo secrets: ANTHROPIC_API_KEY, optionally JIRA_DISPATCH_PAT.
# See docs/consumer-setup.md for the Jira automation rule setup.

on:
  repository_dispatch:
    types: [jira-ticket-ready]

permissions:
  contents: write
  pull-requests: write
  issues: write

jobs:
  develop:
    uses: ${AgenticOwner}/${AgenticRepo}/.github/workflows/reusable-claude-from-jira-node.yml@${AgenticRef}
    with:
      ticket-key:         `${{ github.event.client_payload.ticket_key }}
      ticket-summary:     `${{ github.event.client_payload.summary }}
      ticket-description: `${{ github.event.client_payload.description }}
    secrets:
      anthropic-api-key: `${{ secrets.ANTHROPIC_API_KEY }}
      jira-dispatch-pat: `${{ secrets.JIRA_DISPATCH_PAT }}
"@

    Write-FileOrSkip -Destination (Join-Path $Target '.github\workflows\claude-from-jira.yml') -Content $fromJiraContent
}
elseif ($WithFromJira) {
    Write-Warning "claude-from-jira reusable workflow is only implemented for the 'node' stack so far. Add reusable-claude-from-jira-dotnet.yml in Agentic to extend."
}

# 5. Optional Jira-on-merge sync shim (stack-agnostic).
if ($WithJiraSync) {
    $jiraSyncContent = @"
name: jira-on-merge

# Auto-transition Jira ticket(s) when this PR is merged. Delegates to
# Agentic's reusable workflow. Requires repo secrets JIRA_BASE_URL,
# JIRA_USER_EMAIL, JIRA_API_TOKEN -- see docs/consumer-setup.md.

on:
  pull_request:
    types: [closed]

permissions:
  contents: read
  pull-requests: read

jobs:
  transition:
    if: `${{ github.event.pull_request.merged == true }}
    uses: ${AgenticOwner}/${AgenticRepo}/.github/workflows/reusable-jira-on-merge.yml@${AgenticRef}
    with:
      target-transition-name: 'Done'
    secrets:
      jira-base-url:   `${{ secrets.JIRA_BASE_URL }}
      jira-user-email: `${{ secrets.JIRA_USER_EMAIL }}
      jira-api-token:  `${{ secrets.JIRA_API_TOKEN }}
"@

    Write-FileOrSkip -Destination (Join-Path $Target '.github\workflows\jira-on-merge.yml') -Content $jiraSyncContent
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps for $Target :"
Write-Host "  1. Open the new CLAUDE.md and resolve every <<EDIT ME>> placeholder."
Write-Host "  2. (.NET only) Make sure global.json exists at the repo root pinning the SDK."
Write-Host "  3. Commit the generated files: git add CLAUDE.md .claude .github/workflows/"
if ($WithTier2) {
    Write-Host "  4a. Configure repo secret ANTHROPIC_API_KEY (and optionally PR_BOT_TOKEN) in GitHub repo settings."
}
if ($WithFromJira) {
    Write-Host "  4b. Configure repo secret ANTHROPIC_API_KEY (and optionally JIRA_DISPATCH_PAT)."
    Write-Host "      Set up a Jira automation rule: Label 'agent-ready' -> POST to"
    Write-Host "      https://api.github.com/repos/${AgenticOwner}/<consumer-repo>/dispatches"
    Write-Host "      with event_type=jira-ticket-ready. See docs/consumer-setup.md for the full payload."
}
if ($WithJiraSync) {
    Write-Host "  4c. Configure repo secrets JIRA_BASE_URL, JIRA_USER_EMAIL, JIRA_API_TOKEN in GitHub repo settings."
    Write-Host "      Generate the API token at https://id.atlassian.com/manage-profile/security/api-tokens."
}
Write-Host "  5. Push and confirm the CI workflow runs -- it should report under the 'check' job invoking"
Write-Host "     ${AgenticOwner}/${AgenticRepo}/.github/workflows/reusable-ci-*.yml@${AgenticRef}."
Write-Host ""
Write-Host "To pull updates later: re-run this script with -Force." -ForegroundColor DarkGray
