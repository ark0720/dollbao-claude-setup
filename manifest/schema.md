# Manifest Schema

本文件規定 `manifest/` 下各 JSON 檔的結構。動到 schema 後必須同步所有 `*.json` 並更新本文件。

---

## 1. `common.json` — 全員必裝（Phase 1）

```json
{
  "version": "1",
  "scope": "common",
  "tools": [
    {
      "id": "OpenJS.NodeJS.LTS",
      "name": "Node.js LTS",
      "installer": "winget",
      "verify_cmd": "node --version",
      "fallback_url": "https://nodejs.org/",
      "required": true
    }
  ],
  "skill_bundles": [
    {
      "id": "gws",
      "source": "googleworkspace/cli",
      "lockfile": "skills-lock.json",
      "exclude_patterns": ["persona-*"]
    }
  ],
  "skills": [
    {
      "id": "dollbao-calendar",
      "path": "skills/dollbao-calendar"
    }
  ]
}
```

### 欄位定義

| 欄位 | 型別 | 必要 | 說明 |
|---|---|---|---|
| `version` | string | ✓ | schema 版本，目前 `"1"` |
| `scope` | string | ✓ | `"common"` / `"dept-{key}"` |
| `tools[]` | array | ✓ | 基礎工具項目 |
| `tools[].id` | string | ✓ | winget package id（或 fallback 識別字串） |
| `tools[].name` | string | ✓ | 人類可讀名稱 |
| `tools[].installer` | enum | ✓ | `"winget"` / `"manual"` / `"embedded"` |
| `tools[].verify_cmd` | string | ✓ | 驗證已裝的指令（PowerShell 可跑） |
| `tools[].fallback_url` | string | — | 手動下載 URL（installer != winget 時必要） |
| `tools[].required` | bool | ✓ | `false` 表示可選 |
| `skill_bundles[]` | array | — | 上游 mirror 型 skill 集 |
| `skill_bundles[].id` | string | ✓ | bundle 識別字串（如 `"gws"`） |
| `skill_bundles[].source` | string | ✓ | GitHub repo 路徑（owner/repo） |
| `skill_bundles[].lockfile` | string | ✓ | lock 檔相對於本檔的路徑 |
| `skill_bundles[].exclude_patterns` | array<string> | — | glob 排除規則 |
| `skills[]` | array | — | 自製 skill |
| `skills[].id` | string | ✓ | skill 識別字串（= 資料夾名） |
| `skills[].path` | string | ✓ | 相對 repo root 的路徑 |

---

## 2. `dept-{key}.json` — 部門包（Phase 2 預留）

結構與 `common.json` 相同，並多以下選填欄位：

```json
{
  "version": "1",
  "scope": "dept-marketing-sales",
  "google_group": "marketing@dollbao.com",
  "depends_on": ["common"],
  "tools": [],
  "skills": [],
  "mcps": [
    {
      "id": "windsor-mcp",
      "name": "Windsor MCP (FB 廣告 / LINE OA 推播)",
      "install_method": "npm",
      "package": "@windsor/mcp",
      "config_required": ["WINDSOR_API_KEY"]
    }
  ]
}
```

| 額外欄位 | 型別 | 說明 |
|---|---|---|
| `google_group` | string | 控管 IAM / 部門判定用 |
| `depends_on` | array<string> | 依賴的其他 manifest（一般是 `"common"`） |
| `mcps[]` | array | MCP server 設定（部門才會用） |
| `mcps[].install_method` | enum | `"npm"` / `"pip"` / `"binary"` |
| `mcps[].package` | string | package 名 |
| `mcps[].config_required` | array<string> | 需從用戶取得的設定鍵名（API key 等） |

⚠️ Phase 2 才會有 `dept-*.json`。Phase 1 階段本節僅作為預留說明。

---

## 3. `skills-lock.json` — gws bundle 鎖版

```json
{
  "version": "1",
  "source_repo": "googleworkspace/cli",
  "source_commit": "a3768d0e82ad83cca2da97724e46bea4ff0e6dbd",
  "generated_at": "2026-05-15T00:00:00Z",
  "generator": "scripts/helpers/generate-skills-lock.ps1",
  "_note": "blob_sha1 is git blob SHA1 (verifiable via git hash-object). manifest/common.json exclude_patterns filters persona-* at install time.",
  "total_skills": 95,
  "skills": [
    {
      "name": "gws-gmail-triage",
      "path": "skills/gws-gmail-triage/SKILL.md",
      "blob_sha1": "641a2d114105f9ad73cc229bef6edb5e757ac36d",
      "size": 1219
    }
  ]
}
```

| 欄位 | 說明 |
|---|---|
| `source_repo` | 上游 GitHub repo（owner/repo） |
| `source_commit` | 上游 commit hash（**不能** 含 `HEAD`、`main` 等浮動 ref） |
| `generated_at` | ISO 8601 UTC timestamp |
| `generator` | 產生本 lock 的工具識別（記錄方便 audit） |
| `_note` | 給未來 maintainer 的提示，可選 |
| `total_skills` | skills 陣列長度（含 persona-*）— sanity check 用 |
| `skills[].name` | skill 識別字串 |
| `skills[].path` | 在上游 repo 內的相對路徑 |
| `skills[].blob_sha1` | git blob SHA1（同 `git hash-object SKILL.md`），跨平台穩定，可驗證 |
| `skills[].size` | 檔案大小（bytes），sanity check 用 |

**為什麼用 git blob SHA1 而非 SHA256：**
- 上游 GitHub API 直接回傳這個值，產 lock 時不必本地計算
- 安裝者本機 `git clone` 後可用 `git hash-object` 直接驗證（git 必裝項目）
- 跨平台一致（git 內部處理 line ending）— SHA256 of raw bytes 會因 CRLF/LF 不同而 mismatch

**重新生成：** 用 `scripts/helpers/generate-skills-lock.ps1`（M2 補完）。

---

## 4. 驗證

`scripts/helpers/validate-manifest.ps1`（M2 補完）會檢查：
- JSON 合法
- `version` / `scope` 必要欄位存在且值合法
- `tools[].installer` ∈ 規定 enum
- `skills[].path` 指向實際存在的資料夾
- `skill_bundles[].lockfile` 存在且合法
- 無重複 `id`

CI（`.github/workflows/verify.yml`）每次 PR 跑一次。
