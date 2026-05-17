# verify-install.ps1
# 完整檢查 dollbao-claude-setup 安裝狀態。
#
# 用法：
#   .\scripts\verify-install.ps1            # 完整檢查（含 hash 抽樣）
#   .\scripts\verify-install.ps1 -Quick     # 跳過 hash 抽樣，加速

param([switch]$Quick)

# 不用 Stop，要把所有問題累積後一次回報
$ErrorActionPreference = "Continue"

$script:errors = @()
$script:warnings = @()
$script:checks = 0

function Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "【$Title】" -ForegroundColor Yellow
}

function Check-Command {
    param([string]$Cmd, [string]$Name)
    $script:checks++
    $found = Get-Command $Cmd -ErrorAction SilentlyContinue
    if ($found) {
        $version = ""
        try {
            $out = & $Cmd --version 2>$null | Select-Object -First 1
            if ($out) { $version = "($($out.ToString().Trim()))" }
        } catch {}
        Write-Host "  ✅ $Name $version" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $Name (找不到 '$Cmd')" -ForegroundColor Red
        $script:errors += $Name
    }
}

function Check-Auth {
    param(
        [string]$Cmd,
        [string[]]$ArgList,
        [string]$Name,
        [string]$SuccessPattern,
        [switch]$WarnOnly
    )
    $script:checks++
    if (-not (Get-Command $Cmd -ErrorAction SilentlyContinue)) {
        Write-Host "  ⚠ $Name (前置 '$Cmd' 還沒裝，跳過)" -ForegroundColor DarkYellow
        $script:warnings += "$Name (前置缺)"
        return
    }
    $output = & $Cmd @ArgList 2>&1 | Out-String
    if ($output -match $SuccessPattern) {
        Write-Host "  ✅ $Name" -ForegroundColor Green
    } else {
        if ($WarnOnly) {
            Write-Host "  ⚠ $Name (未 auth — 用到時再跑 '$Cmd login')" -ForegroundColor DarkYellow
            $script:warnings += $Name
        } else {
            Write-Host "  ❌ $Name" -ForegroundColor Red
            $shortOut = ($output.Trim() -split "`n" | Select-Object -First 2) -join " | "
            Write-Host "     輸出: $shortOut" -ForegroundColor DarkGray
            $script:errors += $Name
        }
    }
}

function Check-SkillFile {
    param([string]$Name)
    $script:checks++
    $path = Join-Path $env:USERPROFILE ".claude\skills\$Name\SKILL.md"
    if (Test-Path $path) {
        $size = (Get-Item $path).Length
        Write-Host "  ✅ $Name ($size bytes)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $Name (找不到 $path)" -ForegroundColor Red
        $script:errors += "skill: $Name"
    }
}

function Check-OAuthConfig {
    # M2.7 起：credentials 從 Secret Manager 拉，repo 內不再有 source 檔。
    # 只檢查本機 ~/.config/gws/client_secret.json 是否到位 + 格式合法。
    $destJson = Join-Path $env:USERPROFILE ".config\gws\client_secret.json"

    $script:checks++
    if (-not (Test-Path $destJson)) {
        Write-Host "  ⚠ 本機 ~/.config/gws/client_secret.json 不存在（INSTALL step 8.5 未跑過）" -ForegroundColor DarkYellow
        Write-Host "     → 若已 gcloud auth login（dollbao.com.tw 帳號），跑：" -ForegroundColor DarkYellow
        Write-Host "       gcloud secrets versions access latest --secret=gws-oauth-client --project=dollbao-gws-cli > $destJson" -ForegroundColor DarkYellow
        $script:warnings += "OAuth config: 本機未拉取（如尚未跑安裝劇本則正常）"
        return
    }
    $destContent = [System.IO.File]::ReadAllText($destJson, [System.Text.UTF8Encoding]::new($false))
    if ($destContent -match "TODO_REPLACE|placeholder") {
        Write-Host "  ❌ 本機 client_secret.json 看起來是舊版 placeholder（gws auth login 必失敗）" -ForegroundColor Red
        Write-Host "     → 重跑 step 8.5 從 Secret Manager 拉新版" -ForegroundColor DarkYellow
        $script:errors += "OAuth config: 本機是 placeholder"
        return
    }
    try {
        $parsed = $destContent | ConvertFrom-Json
        if (-not $parsed.installed.client_id -or -not $parsed.installed.client_secret) {
            Write-Host "  ❌ 本機 client_secret.json 格式不正常（缺 installed.client_id / .client_secret）" -ForegroundColor Red
            $script:errors += "OAuth config: 格式錯誤"
            return
        }
        $clientIdShort = $parsed.installed.client_id.Substring(0, [Math]::Min(12, $parsed.installed.client_id.Length))
        Write-Host "  ✅ 本機 client_secret.json 已配置（client_id: ${clientIdShort}...）" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ 本機 client_secret.json 不是合法 JSON" -ForegroundColor Red
        $script:errors += "OAuth config: JSON 解析失敗"
    }
}

function Check-ClaudeDefaults {
    # M2.8: 檢查 ~/.claude/CLAUDE.md 含逗寶 dollbao-defaults 區塊
    $path = Join-Path $env:USERPROFILE ".claude\CLAUDE.md"
    $script:checks++
    if (-not (Test-Path $path)) {
        Write-Host "  ⚠ ~/.claude/CLAUDE.md 不存在（INSTALL step 11.5 未跑過）" -ForegroundColor DarkYellow
        Write-Host "     → 跑 install-claude-defaults.ps1 安裝" -ForegroundColor DarkYellow
        $script:warnings += "Claude defaults: 未安裝"
        return
    }
    $content = [System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))
    if ($content -match "<!-- dollbao-defaults-start") {
        $sizeKb = [Math]::Round($content.Length / 1024, 1)
        Write-Host "  ✅ ~/.claude/CLAUDE.md 已含逗寶 defaults 區塊 (${sizeKb} KB)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ ~/.claude/CLAUDE.md 存在但無 dollbao-defaults 區塊" -ForegroundColor Red
        Write-Host "     → 跑 install-claude-defaults.ps1（會 append 不會覆蓋你既有內容）" -ForegroundColor DarkYellow
        $script:errors += "Claude defaults: 缺 dollbao 區塊"
    }
}

function Sample-Bundle-Integrity {
    param([string]$RepoRoot)
    $lockPath = Join-Path $RepoRoot "manifest\skills-lock.json"
    if (-not (Test-Path $lockPath)) {
        Write-Host "  ⚠ 找不到 $lockPath，跳過抽樣" -ForegroundColor DarkYellow
        $script:warnings += "lock file missing"
        return
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "  ⚠ git 沒裝，跳過抽樣（要驗 blob SHA1 需要 git hash-object）" -ForegroundColor DarkYellow
        $script:warnings += "git missing (sample skipped)"
        return
    }

    $utf8 = [System.Text.UTF8Encoding]::new($false)
    $lock = [System.IO.File]::ReadAllText($lockPath, $utf8) | ConvertFrom-Json

    # 抽 3 個非 persona-* skill：第一個、中間、最後一個
    $candidates = @($lock.skills | Where-Object { -not ($_.name -like 'persona-*') })
    if ($candidates.Count -lt 3) {
        Write-Host "  ⚠ lock 內非 persona-* skill 不到 3 個（$($candidates.Count) 個），跳過抽樣" -ForegroundColor DarkYellow
        return
    }
    $samples = @($candidates[0], $candidates[[int]($candidates.Count / 2)], $candidates[-1])

    foreach ($s in $samples) {
        $script:checks++
        $localPath = Join-Path $env:USERPROFILE ".claude\skills\$($s.name)\SKILL.md"
        if (-not (Test-Path $localPath)) {
            Write-Host "  ❌ $($s.name) (本機未安裝)" -ForegroundColor Red
            $script:errors += "bundle sample: $($s.name) missing"
            continue
        }
        $actual = (git hash-object $localPath 2>$null).Trim()
        if ($actual -eq $s.blob_sha1) {
            Write-Host "  ✅ $($s.name) hash 對齊 lock" -ForegroundColor Green
        } else {
            Write-Host "  ❌ $($s.name) hash mismatch" -ForegroundColor Red
            Write-Host "     expected: $($s.blob_sha1)" -ForegroundColor DarkGray
            Write-Host "     actual:   $actual" -ForegroundColor DarkGray
            $script:errors += "bundle sample: $($s.name) hash mismatch"
        }
    }
}

# ──────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────

# 找 repo root（script 在 scripts/ 下，再上一層）
$repoRoot = Split-Path $PSScriptRoot -Parent

Write-Host ""
Write-Host "🔍 dollbao-claude-setup verify-install" -ForegroundColor Cyan
Write-Host "─────────────────────────────────" -ForegroundColor DarkGray
Write-Host "Repo: $repoRoot"

Section "基礎工具"
Check-Command "node"   "Node.js"
Check-Command "git"    "Git"
Check-Command "gh"     "GitHub CLI"
Check-Command "gcloud" "gcloud CLI (Google Cloud SDK)"
Check-Command "bq"     "bq CLI (BigQuery, Google Cloud SDK)"
Check-Command "npm"    "npm (隨 Node)"
Check-Command "gws"    "gws CLI (Google Workspace CLI)"

Section "Auth 狀態"
Check-Auth -Cmd "gh"     -ArgList @("auth","status") -Name "GitHub CLI 已 auth (warn-only)"   -SuccessPattern "Logged in" -WarnOnly
Check-Auth -Cmd "gws"    -ArgList @("auth","status") -Name "gws CLI 已 auth"                  -SuccessPattern "(?i)(logged in|authenticated|active|email)"
Check-Auth -Cmd "gcloud" -ArgList @("auth","list")   -Name "gcloud CLI 已 auth (warn-only)"   -SuccessPattern "ACTIVE" -WarnOnly

Section "OAuth client config（gws，從 Secret Manager 拉到本機）"
Check-OAuthConfig

Section "自製 skill"
Check-SkillFile "dollbao-calendar"

Section "Claude defaults (~/.claude/CLAUDE.md)"
Check-ClaudeDefaults

if (-not $Quick) {
    Section "gws skill bundle 抽樣（3 個）"
    Sample-Bundle-Integrity -RepoRoot $repoRoot
} else {
    Write-Host ""
    Write-Host "（-Quick 模式，跳過 gws bundle hash 抽樣）" -ForegroundColor DarkGray
}

# ── Summary ──
Write-Host ""
Write-Host "─────────────────────────────────" -ForegroundColor DarkGray
Write-Host "檢查項目：$($script:checks)"
$errCount = $script:errors.Count
$warnCount = $script:warnings.Count

if ($warnCount -gt 0) {
    Write-Host "⚠  $warnCount 項警告（可忽略）：" -ForegroundColor DarkYellow
    $script:warnings | ForEach-Object { Write-Host "    - $_" -ForegroundColor DarkYellow }
}

if ($errCount -eq 0) {
    Write-Host ""
    Write-Host "✨ 所有必要檢查通過！" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "❌ $errCount 項未通過：" -ForegroundColor Red
    $script:errors | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "請回到 Claude Code 視窗，把上面紅色錯誤訊息貼給 AI，讓它協助處理。" -ForegroundColor Yellow
    exit 1
}
