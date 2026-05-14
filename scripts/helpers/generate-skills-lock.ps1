# generate-skills-lock.ps1
# 重新生成 manifest/skills-lock.json，反映上游 googleworkspace/cli 最新 commit。
#
# 用法：
#   .\scripts\helpers\generate-skills-lock.ps1              # 用上游 main 最新 commit
#   .\scripts\helpers\generate-skills-lock.ps1 -Commit abc  # 指定 commit
#
# 前置：
#   - gh CLI 已 auth（gh auth status）
#   - 在 repo root 跑

param(
    [string]$Commit = "",
    [string]$Repo = "googleworkspace/cli"
)

$ErrorActionPreference = "Stop"

if (-not $Commit) {
    Write-Host "查詢上游 $Repo main 最新 commit..." -ForegroundColor Cyan
    $Commit = (gh api "repos/$Repo/commits/main" --jq '.sha').Trim()
    Write-Host "  → $Commit"
}

Write-Host ""
Write-Host "拉取 skill tree at $($Commit.Substring(0, 10))..." -ForegroundColor Cyan
$treeJson = gh api "repos/$Repo/git/trees/$($Commit)?recursive=1" --jq '.tree[] | select(.path | startswith(`"skills/`") and endswith(`"SKILL.md`")) | {path, sha, size}'

$skills = @()
foreach ($line in ($treeJson -split "`n" | Where-Object { $_ })) {
    $entry = $line | ConvertFrom-Json
    if ($entry.path -match '^skills/([^/]+)/SKILL\.md$') {
        $skills += [PSCustomObject]@{
            name      = $matches[1]
            path      = $entry.path
            blob_sha1 = $entry.sha
            size      = $entry.size
        }
    }
}

$skills = $skills | Sort-Object name

if ($skills.Count -eq 0) {
    throw "上游 commit $Commit 沒找到任何 skill。停手。"
}

$lock = [ordered]@{
    version       = "1"
    source_repo   = $Repo
    source_commit = $Commit
    generated_at  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    generator     = "scripts/helpers/generate-skills-lock.ps1"
    _note         = "blob_sha1 is git blob SHA1 (verifiable via git hash-object). manifest/common.json exclude_patterns filters persona-* at install time."
    total_skills  = $skills.Count
    skills        = $skills
}

# Repo root = 兩層上去（scripts/helpers → scripts → repo root）
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$outPath = Join-Path $repoRoot "manifest\skills-lock.json"

$lock | ConvertTo-Json -Depth 5 | Set-Content -Path $outPath -Encoding utf8

$personaCount = ($skills | Where-Object { $_.name -like 'persona-*' }).Count

Write-Host ""
Write-Host "✅ 寫入 $outPath" -ForegroundColor Green
Write-Host "   total: $($skills.Count) skill"
Write-Host "   persona-*: $personaCount（安裝時排除）"
Write-Host "   會安裝: $($skills.Count - $personaCount)"
Write-Host ""
Write-Host "下一步：" -ForegroundColor Yellow
Write-Host "  git diff manifest/skills-lock.json    # 看上游有什麼變動"
Write-Host "  若有 BREAKING（skill 移除 / frontmatter 改）→ PR 描述要標註（見 MAINTAINER.md §10）"
