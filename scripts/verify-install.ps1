# verify-install.ps1
# 自動檢查 dollbao-claude-setup 安裝是否完整。
# ⏸️ M2 階段填完。M1 為骨架，可立即跑（會檢查基礎工具）。

Write-Host ""
Write-Host "🔍 dollbao-claude-setup verify-install" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

$script:errors = @()
$script:warnings = @()

function Check-Command {
    param([string]$Cmd, [string]$Name)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) {
        $version = ""
        try { $version = (& $Cmd --version 2>$null | Select-Object -First 1) } catch { }
        Write-Host "  ✅ $Name $(if ($version) { "($version)" })" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $Name (找不到指令 '$Cmd')" -ForegroundColor Red
        $script:errors += $Name
    }
}

function Check-Skill {
    param([string]$SkillName)
    $skillPath = Join-Path $env:USERPROFILE ".claude\skills\$SkillName\SKILL.md"
    if (Test-Path $skillPath) {
        Write-Host "  ✅ skill: $SkillName" -ForegroundColor Green
    } else {
        Write-Host "  ❌ skill: $SkillName (找不到 $skillPath)" -ForegroundColor Red
        $script:errors += "skill:$SkillName"
    }
}

Write-Host "【基礎工具】" -ForegroundColor Yellow
Check-Command "node"   "Node.js"
Check-Command "git"    "Git"
Check-Command "gh"     "GitHub CLI"
Check-Command "gcloud" "Google Cloud SDK"
Check-Command "bq"     "BigQuery CLI"
Write-Host ""

# ⏸️ M2 補：gws CLI 檢查
# Write-Host "【gws CLI】" -ForegroundColor Yellow
# Check-Command "gws" "gws CLI"

# ⏸️ M2 補：自製 skill 檢查
# Write-Host "【自製 skill】" -ForegroundColor Yellow
# Check-Skill "dollbao-handbook"
# Check-Skill "dollbao-calendar"

# ⏸️ M2 補：auth 狀態檢查（gh / gws / gcloud）
# 範例：
#   gh auth status
#   gws auth status
#   gcloud auth list

Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray
if ($script:errors.Count -eq 0) {
    Write-Host "✨ 所有檢查通過！" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️  $($script:errors.Count) 項未通過：$($script:errors -join ', ')" -ForegroundColor Red
    Write-Host "請回到 Claude Code 視窗，貼上錯誤訊息讓 AI 協助處理。" -ForegroundColor Yellow
    exit 1
}
