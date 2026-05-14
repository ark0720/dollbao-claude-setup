# install-dollbao-skills.ps1
# 把 repo 內 skills/ 底下「列在 manifest/common.json 的 skills[] 陣列」的自製 skill
# 複製到 ~/.claude/skills/。Idempotent — 已存在且 hash 一致則 skip。

param(
    [switch]$DryRun,
    [switch]$Force,
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$commonPath = Join-Path $RepoRoot "manifest\common.json"
if (-not (Test-Path $commonPath)) { throw "找不到 $commonPath" }

Write-Host ""
Write-Host "📦 自製 skill (dollbao-*) 安裝" -ForegroundColor Cyan
Write-Host "─────────────────────────────────" -ForegroundColor DarkGray

# Read JSON as UTF-8 explicitly (PS 5.1 Get-Content uses ANSI on non-BOM files)
$common = [System.IO.File]::ReadAllText($commonPath, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
$skills = @($common.skills)

if ($skills.Count -eq 0) {
    Write-Host "common.json skills[] 是空的，沒事可做" -ForegroundColor Yellow
    exit 0
}

$skillNames = ($skills | ForEach-Object { $_.id }) -join ', '
Write-Host "要安裝 $($skills.Count) 個自製 skill：$skillNames"
Write-Host ""

$dest = Join-Path $env:USERPROFILE ".claude\skills"
if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $dest | Out-Null }

$installed = 0
$skipped = 0
$missing = @()

foreach ($skill in $skills) {
    $srcDir = Join-Path $RepoRoot $skill.path
    if (-not (Test-Path $srcDir)) {
        $missing += $skill.id
        continue
    }

    $srcFile = Join-Path $srcDir "SKILL.md"
    if (-not (Test-Path $srcFile)) {
        Write-Warning "  ⚠ $($skill.id) 沒有 SKILL.md（path: $srcDir）"
        continue
    }

    $destDir = Join-Path $dest $skill.id
    $destFile = Join-Path $destDir "SKILL.md"

    if ((-not $Force) -and (Test-Path $destFile)) {
        $srcHash = (Get-FileHash $srcFile -Algorithm SHA256).Hash
        $destHash = (Get-FileHash $destFile -Algorithm SHA256).Hash
        if ($srcHash -eq $destHash) {
            Write-Host "  ✓ $($skill.id) (already up-to-date)" -ForegroundColor DarkGray
            $skipped++
            continue
        }
    }

    if ($DryRun) {
        Write-Host "  [dry-run] would copy $($skill.id)" -ForegroundColor DarkGray
        $installed++
        continue
    }

    # 整個 skill 資料夾複製（未來 skill 可能有 reference docs / sub-files）
    if (Test-Path $destDir) { Remove-Item -Recurse -Force $destDir }
    Copy-Item -Path $srcDir -Destination $destDir -Recurse -Force
    Write-Host "  ✅ $($skill.id)" -ForegroundColor Green
    $installed++
}

Write-Host "─────────────────────────────────" -ForegroundColor DarkGray
Write-Host "已安裝 / 更新：$installed" -ForegroundColor Green
Write-Host "已存在 (skip)：$skipped" -ForegroundColor DarkGray

if ($missing.Count -gt 0) {
    Write-Host "❌ repo 缺檔：" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
}

if (-not $DryRun) {
    Write-Host ""
    Write-Host "✨ 自製 skill 安裝完成" -ForegroundColor Green
    Write-Host "   下一步：重啟 Claude Code 載入新 skill" -ForegroundColor Yellow
}
