# install-gws-bundle.ps1
# 從 manifest/skills-lock.json 指定的 commit 把 gws skill bundle 安裝到 ~/.claude/skills/
#
# 用法：
#   .\scripts\helpers\install-gws-bundle.ps1            # 正式安裝
#   .\scripts\helpers\install-gws-bundle.ps1 -DryRun    # 只看會做什麼
#   .\scripts\helpers\install-gws-bundle.ps1 -Force     # 即使 hash 已對也重複覆蓋
#
# 前置：
#   - git 已裝（驗 hash + clone 上游用）
#   - 已在 dollbao-claude-setup repo root 跑（或子目錄都行，script 自會找）

param(
    [switch]$DryRun,
    [switch]$Force,
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"

function Resolve-RepoRoot {
    if ($RepoRoot) { return $RepoRoot }
    # scripts/helpers/install-gws-bundle.ps1 → 上兩層 = repo root
    return Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$repoRoot = Resolve-RepoRoot
$lockPath = Join-Path $repoRoot "manifest\skills-lock.json"
$commonPath = Join-Path $repoRoot "manifest\common.json"

if (-not (Test-Path $lockPath)) { throw "找不到 $lockPath" }
if (-not (Test-Path $commonPath)) { throw "找不到 $commonPath" }

Write-Host ""
Write-Host "📦 gws skill bundle 安裝" -ForegroundColor Cyan
Write-Host "─────────────────────────────────" -ForegroundColor DarkGray

$lock = Get-Content $lockPath -Raw | ConvertFrom-Json
$common = Get-Content $commonPath -Raw | ConvertFrom-Json

$bundle = $common.skill_bundles | Where-Object { $_.id -eq "gws" }
if (-not $bundle) { throw "common.json 沒有 id=gws 的 skill_bundle" }

$excludePatterns = @($bundle.exclude_patterns)
Write-Host "Lock commit:      $($lock.source_commit.Substring(0, 10))..."
Write-Host "Upstream repo:    $($lock.source_repo)"
Write-Host "Exclude patterns: $($excludePatterns -join ', ')"
Write-Host ""

# 過濾要裝的 skill
$toInstall = $lock.skills | Where-Object {
    $name = $_.name
    $excluded = $false
    foreach ($pat in $excludePatterns) {
        if ($name -like $pat) { $excluded = $true; break }
    }
    -not $excluded
}
Write-Host "要安裝 $($toInstall.Count) 個 skill（從 lock 的 $($lock.skills.Count) 個過濾）"

# 檢查 git 可用
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git 沒裝。請先跑 winget install Git.Git 後再來。"
}

# Clone 上游到 temp（or 重用既有 clone）
$tmp = Join-Path $env:TEMP "dollbao-gws-mirror"
if (Test-Path $tmp) {
    Write-Host ""
    Write-Host "重用既有 mirror $tmp" -ForegroundColor DarkGray
    $currentCommit = (git -C $tmp rev-parse HEAD 2>$null).Trim()
    if ($currentCommit -ne $lock.source_commit) {
        Write-Host "  目前 commit $($currentCommit.Substring(0,10)) ≠ lock，重新 fetch + checkout"
        git -C $tmp fetch --quiet origin
        git -C $tmp checkout --quiet $lock.source_commit
    } else {
        Write-Host "  commit 已對齊 lock ($($currentCommit.Substring(0,10)))"
    }
} else {
    Write-Host ""
    Write-Host "git clone https://github.com/$($lock.source_repo) → $tmp" -ForegroundColor Cyan
    git clone --quiet "https://github.com/$($lock.source_repo)" $tmp
    if ($LASTEXITCODE -ne 0) { throw "git clone 失敗" }
    git -C $tmp checkout --quiet $lock.source_commit
    if ($LASTEXITCODE -ne 0) { throw "git checkout 失敗" }
    Write-Host "  ✅ 已 pin 到 $($lock.source_commit.Substring(0, 10))" -ForegroundColor Green
}

# 安裝目標
$dest = Join-Path $env:USERPROFILE ".claude\skills"
if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $dest | Out-Null }
Write-Host ""
Write-Host "目標：$dest"
Write-Host ""

# 逐個驗 + 複製
$installed = 0
$skipped = 0
$mismatched = @()
$missing = @()

foreach ($skill in $toInstall) {
    $src = Join-Path $tmp $skill.path
    if (-not (Test-Path $src)) {
        $missing += $skill.name
        continue
    }

    # 驗 git blob SHA1
    $actualSha = (git hash-object $src 2>$null).Trim()
    if ($actualSha -ne $skill.blob_sha1) {
        $mismatched += [PSCustomObject]@{
            name     = $skill.name
            expected = $skill.blob_sha1
            actual   = $actualSha
        }
        continue
    }

    $skillDir = Join-Path $dest $skill.name
    $destFile = Join-Path $skillDir "SKILL.md"

    # idempotent：若 dest 已存在且 hash 對，跳過（除非 -Force）
    if ((-not $Force) -and (Test-Path $destFile)) {
        $destSha = (git hash-object $destFile 2>$null).Trim()
        if ($destSha -eq $skill.blob_sha1) {
            $skipped++
            continue
        }
    }

    if ($DryRun) {
        Write-Host "  [dry-run] would install $($skill.name)" -ForegroundColor DarkGray
        $installed++
        continue
    }

    New-Item -ItemType Directory -Force -Path $skillDir | Out-Null
    Copy-Item -Path $src -Destination $destFile -Force
    $installed++
}

# 結果
Write-Host "─────────────────────────────────" -ForegroundColor DarkGray
Write-Host "已安裝 / 更新：$installed" -ForegroundColor Green
Write-Host "已存在 (skip)：$skipped" -ForegroundColor DarkGray

if ($missing.Count -gt 0) {
    Write-Host "上游缺檔：$($missing.Count)" -ForegroundColor Yellow
    $missing | ForEach-Object { Write-Host "  ⚠ $_" -ForegroundColor Yellow }
    Write-Host "  → lock 與上游不一致，請重跑 generate-skills-lock.ps1" -ForegroundColor Yellow
}

if ($mismatched.Count -gt 0) {
    Write-Host ""
    Write-Host "❌ Hash 不對 ($($mismatched.Count) 個)：" -ForegroundColor Red
    $mismatched | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Red
    Write-Host "  → 上游內容已變動但 lock 沒更新。請重跑 generate-skills-lock.ps1" -ForegroundColor Yellow
    exit 1
}

if ($DryRun) {
    Write-Host ""
    Write-Host "（dry-run 模式，沒有實際寫入）" -ForegroundColor DarkGray
} else {
    Write-Host ""
    Write-Host "✨ gws skill bundle 安裝完成" -ForegroundColor Green
    Write-Host "   下一步：重啟 Claude Code，輸入 /gws-gmail-triage 之類驗證觸發" -ForegroundColor Yellow
}
