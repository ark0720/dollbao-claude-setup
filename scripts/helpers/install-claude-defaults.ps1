# install-claude-defaults.ps1
# 把 templates/claude-defaults.md 安裝到 ~/.claude/CLAUDE.md。
# 3 種情境都 idempotent：
#   - 檔案不存在 → 直接寫入整段 template
#   - 檔案存在但無 dollbao 區塊 → append 到末尾
#   - 檔案存在且已有 dollbao 區塊 → 取代 marker 之間的內容（user 其他內容不動）

param(
    [switch]$DryRun,
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$templatePath = Join-Path $RepoRoot "templates\claude-defaults.md"
$destPath = Join-Path $env:USERPROFILE ".claude\CLAUDE.md"

if (-not (Test-Path $templatePath)) {
    throw "找不到 template: $templatePath"
}

$utf8 = [System.Text.UTF8Encoding]::new($false)
$templateContent = [System.IO.File]::ReadAllText($templatePath, $utf8).TrimEnd() + "`n"

$startMarker = "<!-- dollbao-defaults-start"
$endMarker = "<!-- dollbao-defaults-end -->"

Write-Host ""
Write-Host "📋 安裝逗寶 Claude defaults" -ForegroundColor Cyan
Write-Host "─────────────────────────────────" -ForegroundColor DarkGray
Write-Host "Template: $templatePath"
Write-Host "目標：    $destPath"
Write-Host ""

# 確保目標目錄存在
$destDir = Split-Path $destPath -Parent
if (-not (Test-Path $destDir)) {
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }
}

$action = ""
$newContent = ""

if (-not (Test-Path $destPath)) {
    # Case 1: 沒有既有 CLAUDE.md
    $newContent = $templateContent
    $action = "create"
    Write-Host "  情境：CLAUDE.md 不存在 → 新建" -ForegroundColor Yellow
} else {
    $existing = [System.IO.File]::ReadAllText($destPath, $utf8)
    $startIdx = $existing.IndexOf($startMarker)
    $endIdx = $existing.IndexOf($endMarker)

    if ($startIdx -eq -1) {
        # Case 2: 既有檔案但沒 dollbao 區塊 → append
        $newContent = $existing.TrimEnd() + "`n`n" + $templateContent
        $action = "append"
        Write-Host "  情境：CLAUDE.md 存在但無逗寶區塊 → append 到末尾" -ForegroundColor Yellow
        Write-Host "  既有檔案大小：$($existing.Length) chars（保留不動）" -ForegroundColor DarkGray
    } else {
        # Case 3: 既有檔案且有 dollbao 區塊 → 取代區塊內容（user 其他內容不動）
        if ($endIdx -eq -1 -or $endIdx -lt $startIdx) {
            throw "$destPath 內 dollbao 區塊 marker 不完整（start 找到但 end 沒找到，或順序錯亂）— 請手動處理"
        }
        $endIdx = $endIdx + $endMarker.Length
        $before = $existing.Substring(0, $startIdx)
        $after = $existing.Substring($endIdx)
        # 用 TrimStart 清掉 marker 後緊接的空白行，TrimEnd 清掉 template 結尾多餘空白
        $newContent = $before + $templateContent.TrimEnd() + "`n" + $after.TrimStart()
        $action = "update"
        Write-Host "  情境：已有逗寶區塊 → 取代區塊內容（user 其他段落不動）" -ForegroundColor Yellow
    }
}

if ($DryRun) {
    Write-Host ""
    Write-Host "  [dry-run] action: $action" -ForegroundColor DarkGray
    Write-Host "  [dry-run] 目標檔大小（寫入後）：$($newContent.Length) chars" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "（dry-run 模式，沒有實際寫入）" -ForegroundColor DarkGray
    return
}

# 寫回（UTF-8 無 BOM，markdown convention）
[System.IO.File]::WriteAllText($destPath, $newContent, $utf8)

Write-Host ""
Write-Host "✅ $action $destPath ($($newContent.Length) chars)" -ForegroundColor Green
Write-Host ""
Write-Host "下一步：重啟 Claude Code，新行為原則才會載入" -ForegroundColor Yellow
