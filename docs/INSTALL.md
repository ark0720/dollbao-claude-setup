# INSTALL.md — 逗寶新人 Claude Code 安裝劇本

> 這份文件是給 **Claude AI** 讀的。當新人貼完 bootstrap prompt 後，AI 會依本劇本一步步引導。
>
> Steps 1-11.5 全部填完。Step 12（verify-install 成功判準）待 M2.4 補完。

---

## 0. 對話原則

1. **繁體中文** — 所有訊息用繁體中文，工具名稱保留原文（winget、gh、gws、bq、npm...）
2. **每步驟先確認再動手** — 跑 `winget install` 前先說「我接下來要裝 Node.js LTS，約需 1 分鐘，可以嗎？」等用戶 OK 再跑
3. **失敗給明確中文錯誤** — 不要只貼英文 stack trace；先用人話說「網路抓不到 package」再附原始錯誤
4. **Idempotent** — 已裝的工具用 `Get-Command` 偵測到就 skip 並告知用戶「Node.js 已裝（v20.x），跳過此步驟」
5. **避免假設工程背景** — 對非工程同事用「桌面、檔案總管」等日常詞彙，不用「shell、stdout、env var」
6. **完成一個 milestone 後給進度條** — 「目前進度 3/13」
7. **失敗時優先AI查找並設法解決** — 所有「找 IT」最後都會繞回 ark0720。所以遇錯先把本文件列的自救步驟跑完（重試、診斷網路、檢查帳號、查 log、改 config）。**只有自救無解的硬擋**（IAM 沒設、Secret 不存在、Windows 物理太舊、公司 firewall 白名單）才回報 ark0720。回報時要附：(a) 完整錯誤訊息原文；(b) 已嘗試過的自救步驟與其結果；(c) 用戶當前帳號 / 環境的關鍵資訊。**不要動不動就丟「請聯絡 IT」三個字給用戶。**

---

## 1. 安裝步驟總覽

| # | 步驟 | 工具 / 動作 | 預計時間 |
|---|---|---|---|
| 1 | 環境檢查 | PowerShell 偵測 Windows / winget / 網路 | 30 秒 |
| 2 | 裝 Node.js LTS | `winget install OpenJS.NodeJS.LTS` | 2 分鐘 |
| 3 | 裝 Git | `winget install Git.Git` | 1 分鐘 |
| 5 | 裝 Google Cloud SDK (含 gcloud + bq CLI) | `winget install Google.CloudSDK` | 3 分鐘 |
| **5.5** | **`gcloud auth login`** | 引導瀏覽器授權（用公司 dollbao.com.tw 帳號）| 1 分鐘 |
| 7 | Clone setup repo | `git clone https://github.com/ark0720/dollbao-claude-setup.git $env:USERPROFILE\.claude\dollbao-setup` | 30 秒 |
| **8** | **裝 gws CLI** | `npm install -g @googleworkspace/cli` | 1 分鐘 |
| **8.5** | **取 gws OAuth client** | `gcloud secrets versions access latest --secret=gws-oauth-client --project=dollbao-gws-cli` → `~/.config/gws/client_secret.json` | 5 秒 |
| 9 | `gws auth login --scopes ...` | 引導瀏覽器授權（明確 scope 清單；**不要用 `--full`**，那只多 pubsub+cloud-platform）| 1 分鐘 |
| 10 | 裝 gws skill bundle | 跑 `~/.claude/dollbao-setup/scripts/helpers/install-gws-bundle.ps1`（依 `manifest/skills-lock.json` 拉 ~85 個非 persona-* skill 到 `~/.claude/skills/`） | 2 分鐘 |
| 11 | 裝自製 skill | 跑 `~/.claude/dollbao-setup/scripts/helpers/install-dollbao-skills.ps1`（依 `manifest/common.json` 的 `skills[]` 複製到 `~/.claude/skills/`） | 30 秒 |
| **11.5** | **裝逗寶共用 Claude defaults** | 跑 `~/.claude/dollbao-setup/scripts/helpers/install-claude-defaults.ps1`（把行為原則寫進 `~/.claude/CLAUDE.md`，所有 session 自動載入） | 5 秒 |
| 12 | `verify-install.ps1` | 自動檢查所有工具 / skill 都裝好 | 30 秒 |
| 13 | 5 題驗證 | AI 出題、用戶答 | 5 分鐘 |

**總計：約 20 分鐘。**（含 step 5.5 gcloud auth login 1 分鐘 + step 8.5 從 Secret Manager 拉 credentials 5 秒）

---

## 2. 各步驟細節

### 步驟 1：環境檢查
- **意圖：** 確認 Windows 版本、winget 可用、有網路
- **指令：**
  ```powershell
  # Windows 版本（需 Win10 1809+ build 17763 或 Win11 build 22000+）
  $os = Get-CimInstance Win32_OperatingSystem
  Write-Host "$($os.Caption) (Build $($os.BuildNumber))"

  # winget 可用性
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if ($winget) { winget --version }

  # 網路（winget source + GitHub）
  Test-NetConnection cdn.winget.microsoft.com -Port 443 -InformationLevel Quiet
  Test-NetConnection github.com -Port 443 -InformationLevel Quiet
  ```
- **成功判準：**
  - `$os.BuildNumber` ≥ 17763（Win10 1809）或 ≥ 22000（Win11）
  - `winget --version` 回傳 v1.6 或更新
  - 兩個 `Test-NetConnection` 都 `True`
- **失敗 fallback（自救優先，§0.7）：**
  - **Windows 太舊（< 17763）：**
    1. 引導 user 開「設定 > Windows Update > 檢查更新」自動升級
    2. 若 update 卡住，跑 `Get-WindowsUpdateLog` 看 log
    3. 重試一次。三輪仍卡 < 17763 → 回報 ark0720（可能要重灌系統）
  - **winget 不存在：**
    1. 先試重新註冊 App Installer：
       ```powershell
       Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
       ```
    2. 不行 → 下載最新 .msixbundle 安裝：
       ```powershell
       $tmp = "$env:TEMP\winget.msixbundle"
       Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile $tmp
       Add-AppxPackage -Path $tmp
       ```
    3. 都失敗 → 收齊錯誤回報 ark0720
  - **winget source / github 連不通：**
    1. `Get-NetConnectionProfile` 看當前網路（公司 / VPN / 家用）
    2. `netsh winhttp show proxy` 看系統 proxy 設定；`$env:HTTPS_PROXY`、`$env:HTTP_PROXY`
    3. `Resolve-DnsName github.com -Type A` 看 DNS 是否解得到
    4. 有 VPN → 先 disconnect 再 reconnect 重試
    5. `Test-NetConnection github.com -Port 443 -InformationLevel Detailed` 看是 DNS 死還是 TLS 死
    6. 自救無解（DNS 通但 443 連不上、或公司硬擋）→ 把上述診斷輸出整理回報 ark0720（多半要開 firewall 白名單）
- **對話模板：** 「我先幫你檢查環境（Windows 版本、winget 是否可用、網路能不能連到 winget 跟 GitHub）。約 30 秒。」

### 步驟 2-5：裝基礎工具（Node / Git / gcloud）
- **意圖：** 後續工具的前置依賴
- **共用模式：**
  1. `Get-Command {cmd}` 偵測 — 已有 → skip + 告知 user「已裝 (v...)」
  2. 否則跑下表的 winget 指令
  3. **重整 PATH**（不然當前 PowerShell session 找不到新指令）：
     ```powershell
     $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
     ```
  4. 跑 `verify_cmd` 確認
  5. winget 失敗 → 提示 `fallback_url`（見 [`manifest/common.json`](../manifest/common.json)）讓 user 手動下載
- **指令細節：**

  | 工具 | winget 指令 | verify_cmd 成功訊號 |
  |---|---|---|
  | Node.js LTS | `winget install --id OpenJS.NodeJS.LTS --exact --silent --accept-source-agreements --accept-package-agreements` | `node --version` 回 `v20.x` 或更新 |
  | Git | `winget install --id Git.Git --exact --silent --accept-source-agreements --accept-package-agreements` | `git --version` 回 `git version 2.x` |
  | Google Cloud SDK | `winget install --id Google.CloudSDK --exact --silent --accept-source-agreements --accept-package-agreements` | `gcloud --version` 首行含 `Google Cloud SDK`，且 `bq --version` 不報錯（bq 隨 bundle 進來） |

- **對話模板：**
  - Node.js：「我接下來裝 Node.js LTS（約 2 分鐘）。gws CLI 跟很多 skill 都需要它。可以嗎？」
  - Git：「裝 Git（約 1 分鐘）。後面用它把安裝包 repo clone 下來。」
  - Google Cloud SDK：「裝 Google Cloud SDK，會同時帶來 gcloud 和 bq CLI（約 3 分鐘）。逗寶曆 skill 和 Secret Manager 都會用到。」

### 步驟 5.5：`gcloud auth login`
- **意圖：** 員工本人用公司 Google 帳號登入 gcloud，後續：(a) 步驟 8.5 從 Secret Manager 拉 OAuth credentials；(b) 未來 `dollbao-calendar` skill 查 BigQuery 用
- **前置：** Google Cloud SDK 已裝（步驟 5）
- **指令：** `gcloud auth login`
- **成功判準：** `gcloud auth list --filter=status:ACTIVE --format="value(account)"` 回傳 `xxx@dollbao.com.tw`
- **失敗 fallback（自救優先，§0.7）：**
  - **用個人 gmail 登入：** AI 直接跑 `gcloud auth revoke --all` 清掉，再引導重做 `gcloud auth login` 並提醒選公司帳號（不用回報 ark0720）
  - **瀏覽器沒跳出：** AI 用 `gcloud auth login --no-launch-browser` 改成終端機印 URL，請 user 複製到瀏覽器手動開（不用回報 ark0720）
  - **登入後 `gcloud auth list` 仍空：** 跑 `gcloud config list` 看 active config 是否壞掉；`gcloud config configurations list` 看有沒有多個 config 衝突，必要時 `gcloud config configurations activate default`
- **對話模板：** 「我接下來引導你登入 gcloud。請務必用你的 dollbao.com.tw 公司帳號（不是個人 gmail），否則後續取不到公司共用的設定。」

### 步驟 7：Clone setup repo
- **意圖：** 把本 repo 拉到 `~/.claude/dollbao-setup/`
- **指令：** `git clone https://github.com/ark0720/dollbao-claude-setup.git "$env:USERPROFILE\.claude\dollbao-setup"`
- **成功判準：** `Test-Path "$env:USERPROFILE\.claude\dollbao-setup\manifest\common.json"`
- **失敗 fallback（自救優先，§0.7）：**
  - **clone 失敗（網路）：** AI 先自診
    1. `Test-NetConnection github.com -Port 443 -InformationLevel Detailed`
    2. 試 `git config --global http.postBuffer 524288000` 解大檔卡住
    3. 試 `git -c http.sslVerify=false clone ...` 排除憑證問題（成功的話事後再開回 sslVerify）
    4. 自救無解 → 收齊錯誤訊息 + 上述診斷結果回報 ark0720（多半要開公司 firewall 白名單）
  - **目標資料夾已存在：** AI 直接改跑 `git -C "$env:USERPROFILE\.claude\dollbao-setup" pull` 更新（不用回報）
  - **clone 失敗（權限）：** repo 是 public 應該不會發生；若發生先檢查 `git config --list` 看是不是被誤設了 `http.extraheader` 帶錯 token

### 步驟 8：裝 gws CLI
- **意圖：** gws CLI 是所有 gws-* / recipe-* skill 的執行引擎（skill 內呼叫 `gws gmail +triage` 之類）
- **前置：** Node.js 已裝（步驟 2）
- **指令：**
  ```powershell
  npm install -g @googleworkspace/cli
  ```
- **成功判準：**
  ```powershell
  gws --version  # 應回傳 0.22.x 或更新
  ```
- **失敗 fallback（自救優先，§0.7）：**
  - **npm install 失敗：** AI 依序試
    1. 確認 Node 真的裝起來：`node --version` + `npm --version` 都要過
    2. `npm cache clean --force` 後重試
    3. `npm config set registry https://registry.npmjs.org/`（解 proxy 問題）後重試
    4. 用管理員 PowerShell（`Start-Process powershell -Verb RunAs`）重試
    5. 都失敗 → 從 https://github.com/googleworkspace/cli/releases 下載 binary 手動裝
    6. 連 release 頁也連不上 → 收齊錯誤回報 ark0720（網路硬擋）
  - **PATH 找不到 `gws`：** AI 直接重整 PATH 不用重啟 PowerShell：
    ```powershell
    $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
    ```
- **對話模板：** 「我接下來裝 Google Workspace CLI（gws），所有 gws-* skill 都靠它運作。約需 1 分鐘。可以嗎？」

### 步驟 8.5：從 Secret Manager 取 gws OAuth client
- **意圖：** gws CLI 跟 Google API 對話需要一組 OAuth client credentials。逗寶把這份 credentials 存在 GCP Secret Manager (`projects/dollbao-gws-cli/secrets/gws-oauth-client`)，IAM 限定 `domain:dollbao.com.tw`，新人本機透過 gcloud 拉取。
- **前置：** gcloud 已 auth 為 dollbao.com.tw 帳號（步驟 5.5）+ gws CLI 已裝（步驟 8）
- **指令：**
  ```powershell
  $gwsCfg = Join-Path $env:USERPROFILE ".config\gws"
  New-Item -ItemType Directory -Force -Path $gwsCfg | Out-Null
  $secretJson = gcloud secrets versions access latest `
    --secret=gws-oauth-client `
    --project=dollbao-gws-cli 2>&1
  if ($LASTEXITCODE -ne 0) {
      Write-Error "拉取 secret 失敗：$secretJson"
      throw "拉取失敗，依錯誤碼跑 fallback：PERMISSION_DENIED → 換 dollbao.com.tw 帳號；NOT_FOUND → 跑 gcloud secrets list 自診斷後再回報 ark0720"
  }
  $secretJson | Set-Content -Path (Join-Path $gwsCfg "client_secret.json") -Encoding utf8 -NoNewline
  ```
- **成功判準：**
  - `Test-Path "$env:USERPROFILE\.config\gws\client_secret.json"` ✅
  - 檔案不為空且含合法 JSON（用 `Get-Content ... | ConvertFrom-Json | Select -ExpandProperty installed` 驗證有 `client_id` / `client_secret` 欄位）
- **失敗 fallback（自救優先，§0.7）：**
  - **`PERMISSION_DENIED`：** AI 依序自診
    1. `gcloud auth list --format="value(account)"` 看當前 active account
    2. 不是 `*@dollbao.com.tw` → `gcloud auth login` 換帳號重試（自救完）
    3. 已是 dollbao.com.tw → 直接重試一次 `gcloud secrets versions access`（token 過期 / 短暫網路抖動常見）
    4. 還不行 → 回報 ark0720：「帳號 `xxx@dollbao.com.tw` 跑 step 8.5 PERMISSION_DENIED，請確認該帳號在 `_HQ@dollbao.com.tw` 群組內」（**注意：** 不要叫 user 跑 `gcloud secrets list` 自診 — IAM 給的是 `secretmanager.secretAccessor` 角色，本來就沒 list 權限，list 失敗不代表 access 失敗）
  - **`NOT_FOUND`：** AI 先確認 secret 真的不存在
    1. `gcloud secrets list --project=dollbao-gws-cli --filter="name~gws-oauth-client"` — 若這個指令本身 PERMISSION_DENIED → 走上面 PERMISSION_DENIED 流程
    2. 若回空 → secret 真的不存在，回報 ark0720：「請在 GCP project `dollbao-gws-cli` 建 secret `gws-oauth-client`（步驟見 `config/README.md`）」
    3. 若 secret 在但版本是 disabled → `gcloud secrets versions list --secret=gws-oauth-client --project=dollbao-gws-cli` 看版本狀態，回報 ark0720
  - **其他錯誤：** 先把錯誤訊息與 `gcloud --version`、`gcloud auth list`、`gcloud config list` 三項輸出整理好，再回報 ark0720
- **對話模板：** 「我接下來從公司 GCP 的 Secret Manager 拉 gws CLI 要用的 OAuth credentials。這只會發生一次，下一步 `gws auth login --scopes ...` 才是綁定你的個人 Workspace 帳號（用明確 scope 清單拿齊 skill 需要的權限；不能用 `--full`，那只多兩個 scope）。」

### 步驟 9：`gws auth login --scopes ...`（用明確 scope 清單，不要 `--full`）
- **意圖：** 把新人的 Google Workspace 帳號 OAuth 授權給 gws CLI
- **前置：** gws CLI 已裝（步驟 8）+ OAuth client 已配置（步驟 8.5）+ admin 已將 gws-cli 升級為 Trusted（一次性後台工作，見 `docs/TROUBLESHOOTING.md` §App-Access-Control）
- **指令：**
  ```powershell
  $scopes = @(
    'https://mail.google.com/',
    'https://www.googleapis.com/auth/drive',
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/documents',
    'https://www.googleapis.com/auth/presentations',
    'https://www.googleapis.com/auth/tasks',
    'https://www.googleapis.com/auth/admin.directory.group',
    'https://www.googleapis.com/auth/admin.directory.group.member',
    'https://www.googleapis.com/auth/admin.reports.audit.readonly',
    'https://www.googleapis.com/auth/cloud-platform',
    'openid',
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile'
  ) -join ','
  gws auth login --scopes $scopes
  ```
- **為什麼不用 `--full`：** 實測 `--full` 只在預設集合（drive / sheets / gmail.modify / calendar / docs / slides / tasks / openid / userinfo）上加 `pubsub + cloud-platform`，**根本不含** `gmail.settings.basic` / `forms` / `keep` / `chat` / `meet` / `contacts` / `classroom` / `script` / `admin.reports`。gws CLI `--help` 的「Request all scopes」描述是誤導；真正的「all」是上述 12 個固定集合，不是「全部 skill 需要的所有 scope」。
- **為什麼用 `https://mail.google.com/` 取代 `gmail.modify`：** `gmail.modify` 只涵蓋訊息 + 標籤讀寫，**不涵蓋 Gmail settings 寫入**（filter / vacation / forwarding）。`https://mail.google.com/` 是 Gmail 最大 scope，涵蓋 messages + settings 全部讀寫，這是 AI 自動化 email（建 filter / 設自動回覆 / 設定轉寄）的必要條件。
- **這 14 個 scope 為什麼是這 14 個：**
  - mail.google.com — Gmail 完整（含 filter / vacation / forwarding 寫入）
  - drive / spreadsheets / documents / presentations — 文件四件套寫入
  - calendar / tasks — 日曆 + 工作
  - admin.directory.group(.member) — Group 成員管理（recipe-share-folder-with-team 等用）
  - admin.reports.audit.readonly — Workspace audit log 查詢（自診斷用：誰登過、誰沒登過）
  - cloud-platform — gcloud / BQ / Secret Manager
  - openid / userinfo.email / userinfo.profile — 身份識別
- **為什麼不一次包更多（如 forms / keep / chat / meet）：** 部分 Workspace API scope 對第三方 OAuth client 有額外限制：
  - `keep` — Google 直接擋（400 invalid_scope）— Google Keep API 對非 first-party app 不開放
  - `chat.messages` / `chat.spaces` / `meetings.space.*` / `forms.*` / `classroom.*` / `script.*` — 可能個別失敗（待逐個驗證），新人裝這些 skill 後跑時若 403 再個別補
  - 加單一壞 scope 會讓 Google 整個 OAuth flow 400 失敗（fail-fast）
- **成功判準：**
  - `gws auth status` 顯示 logged in + 用戶 email
  - `gws auth status --format json` 的 `scope_count == 16`（14 個 scope 拆 email/profile 後 + openid + admin.reports 等 = 約 16）
  - 試跑 `gws gmail users settings filters list --params '{"userId":"me"}'`：不報 403 即正常
- **常見坑：**
  - 用戶用個人 gmail 登入而非公司帳號 → skill 跑起來會權限不足。確認用 `@dollbao.com.tw` 帳號
  - 瀏覽器沒跳出 → 設 `$env:BROWSER='echo'` 後 gws 會把 URL 印到 stdout 給 user 複製
  - 已經跑過 `--full` 或不帶 flag 的 `gws auth login`（舊版 INSTALL.md）→ 直接重跑本步驟以上 `--scopes` 命令補完，**不必先 logout**
  - `filter.create` 跑出 403 ACCESS_TOKEN_SCOPE_INSUFFICIENT 雖然 token 有 mail.google.com → 是 Workspace Admin Console「App Access Control」沒把 gws-cli 升 Trusted（一次性後台工作，見 TROUBLESHOOTING.md）。**設完 Trust 後 Gmail settings 寫入子系統的傳播延遲可達 1–24 小時**（讀 + message 寫立刻通，settings 寫慢）
- **對話模板：** 「我接下來引導你登入 gws CLI，會跳出瀏覽器讓你授權 Google Workspace 存取。我會用明確 scope 清單（14 個）拿包括 Gmail 設定寫入在內的所有日常 skill 需要的權限。**請務必用 dollbao.com.tw 公司帳號**（不是個人 gmail）。瀏覽器沒跳出來的話，把終端機印的 URL 複製到瀏覽器手動開。」

### 步驟 10：裝 gws skill bundle ⭐
- **意圖：** 把 ~85 個 gws-* / recipe-* skill 安裝到 `~/.claude/skills/`（排除 10 個 persona-*）
- **前置：** Git 已裝（步驟 3）、repo 已 clone（步驟 7）
- **指令：**
  ```powershell
  & "$env:USERPROFILE\.claude\dollbao-setup\scripts\helpers\install-gws-bundle.ps1"
  ```
- **背後做什麼：**
  1. 讀 `manifest/skills-lock.json` 拿 pinned commit + 95 個 skill blob_sha1
  2. 讀 `manifest/common.json` 的 `exclude_patterns: ["persona-*"]` 過濾
  3. `git clone googleworkspace/cli` 到 `$env:TEMP\dollbao-gws-mirror`
  4. `git checkout <pinned_commit>`
  5. 逐個 skill：`git hash-object` 驗 blob SHA1 vs lock → 通過則複製到 `~/.claude/skills/{name}/SKILL.md`
  6. 已存在且 hash 一致 → skip（idempotent）
- **支援的 flag：**
  - `-DryRun` 只看會做什麼不動檔
  - `-Force` 即使 hash 已對也覆蓋
- **成功判準：** 腳本最後輸出「✨ gws skill bundle 安裝完成」+ `Test-Path "$env:USERPROFILE\.claude\skills\gws-gmail-triage\SKILL.md"`
- **失敗 fallback（自救優先，§0.7）：**
  - **Hash mismatch：** AI 直接跑 `scripts/helpers/generate-skills-lock.ps1` 重新生 lock，再跑一次 install-gws-bundle.ps1（自救完）。連續兩次仍 mismatch 才回報 ark0720
  - **上游 clone 失敗（網路）：** 跟步驟 7 相同自救流程（Test-NetConnection / proxy / DNS / VPN）。自救無解才回報 ark0720
- **對話模板：** 「我接下來把約 85 個 Google Workspace skill 裝到 Claude Code。會從上游 googleworkspace/cli 用我們鎖定的 commit 抓，逐個驗 hash 才寫入。約需 2 分鐘。」

### 步驟 11：裝自製 skill
- **意圖：** 把本 repo 的 `skills/dollbao-calendar`（以及未來新增的全員 skill）複製到 `~/.claude/skills/`
- **前置：** Repo 已 clone（步驟 7）
- **指令：**
  ```powershell
  & "$env:USERPROFILE\.claude\dollbao-setup\scripts\helpers\install-dollbao-skills.ps1"
  ```
- **背後做什麼：**
  1. 讀 `manifest/common.json` 的 `skills[]` 陣列
  2. 對每個 entry：`Copy-Item` 整個 skill 資料夾到 `~/.claude/skills/{id}/`
  3. 已存在且 SHA256 一致 → skip
- **成功判準：** 腳本輸出 + `Test-Path "$env:USERPROFILE\.claude\skills\dollbao-calendar\SKILL.md"`
- **失敗 fallback：** repo 缺檔 → 多半是 clone 不完整，重跑步驟 7
- **對話模板：** 「裝逗寶自製 skill（逗寶曆查詢），複製 1 個檔案。30 秒。」

### 步驟 11.5：裝逗寶共用 Claude defaults
- **意圖：** 把公司共用的 AI 行為原則（繁中、直接動手、不要 leak secrets 等）寫進 `~/.claude/CLAUDE.md`，**所有** Claude Code session 自動載入（不限本 repo）
- **前置：** Repo 已 clone（步驟 7）
- **指令：**
  ```powershell
  & "$env:USERPROFILE\.claude\dollbao-setup\scripts\helpers\install-claude-defaults.ps1"
  ```
- **背後做什麼：**
  1. 讀 `templates/claude-defaults.md`
  2. 三種情境處理 `~/.claude/CLAUDE.md`：
     - 不存在 → 直接寫入
     - 存在但無 dollbao 區塊 → append 到末尾
     - 存在且有 dollbao 區塊 → 取代 `<!-- dollbao-defaults-start ... -->` 與 `<!-- dollbao-defaults-end -->` 之間（user 其他段落不動）
- **成功判準：** `Test-Path "$env:USERPROFILE\.claude\CLAUDE.md"` ✅ + 內含 `<!-- dollbao-defaults-start` marker
- **失敗 fallback：** 多半是 marker 不完整（user 手動編輯壞了）→ 把舊檔備份後手動清掉 dollbao 區塊重跑
- **對話模板：** 「我接下來把逗寶共用的 AI 行為原則寫到 `~/.claude/CLAUDE.md`，這之後你開任何 Claude Code session AI 都會自動知道用繁中回應、有 tool 就直接跑等公司預設。」

### 步驟 12：跑 `verify-install.ps1`
- **意圖：** 自動檢查所有工具 + skill + auth 都到位
- **指令：**
  ```powershell
  & "$env:USERPROFILE\.claude\dollbao-setup\scripts\verify-install.ps1"
  ```
- **成功判準：** ⏸️ M2.4 補完（依 verify-install.ps1 的最終形式）

### 步驟 13：5 題驗證（見 §4）
- **意圖：** 真實對話驗證新人能用工具
- **流程：** AI 出題 → 用戶答 → AI 評分（見 §4）

---

## 3. 全員 skill 清單（步驟 11 安裝）

| Skill | 型態 | 觸發情境 |
|---|---|---|
| `dollbao-calendar` | BQ 查詢型 | 逗寶報告歷（RY/RQ/RM/RW 編碼、會計年度起訖、週月反查、YoY 比較規則…） |

新增條目時，記得**先讀 MAINTAINER.md §4 判斷歸屬**（個人 / 草稿 / 全員 / 部門），確認是全員 skill 才走 §7 SOP 同步 `manifest/common.json`。

---

## 4. 驗證題（步驟 13）

裝完後 AI 出以下 5 題，看用戶能不能用：

1. **「今天是逗寶曆第幾週？」**
   - 期待觸發：`dollbao-calendar`
   - 期待路徑：跑 BQ query 查 `dollbao-data-center.Ref.reportYearMonthWeek` → 用 RY{YY}W{WW} 格式回答
   - 評分：跑了 bq query +1 / 格式正確 +1 / 失敗時提示 `gcloud auth login` +1

2. **「今天是逗寶曆第幾週？下個檔期什麼時候？」**
   - 期待觸發：`dollbao-calendar`
   - 期待路徑：BQ query 拿週次 → 第二問誠實回答「檔期不在 BQ，請讀規章 Doc」
   - 評分：跑了 bq query +1 / 用 RY{YY}W{WW} 格式輸出 +1 / 檔期部分 fallback 到 Doc +1

3. **「請幫我看今天 Google Calendar 行程」**
   - 期待觸發：`gws-calendar-agenda`
   - 評分：跑了 gws 指令拿到結果 +1

4. **「列出我未讀的 email 摘要」**
   - 期待觸發：`gws-gmail-triage`
   - 評分：跑了 gws 指令拿到結果 +1

5. **「list 我的 GCP project」**
   - 期待跑：`gcloud projects list`
   - 評分：能跑 gcloud（可能還沒 auth，AI 應提示 `gcloud auth login`）+1

---

## 5. Idempotent 原則

- **偵測已裝：** 用 `Get-Command {tool}` 或 `winget list --id {id}`，**不要** 重複跑安裝
- **skill 比 hash：** `install-gws-bundle.ps1` / `install-dollbao-skills.ps1` 內建 hash 比對，已對齊則 skip
- **auth 不重做：** `gws auth status` 顯示 OK **且** `scope_count` 已 ≥ 14 + 含 `https://mail.google.com/` 才 skip step 9；否則需重跑 `gws auth login --scopes ...` 補 scope（舊新人若已跑過 `--full` 或無 flag 的 `gws auth login`，scope 必定不夠，需依本 INSTALL.md 重跑）
- **對話可中斷重來：** 用戶 Ctrl+C 後重貼 bootstrap prompt，AI 應從中斷點繼續而非從頭

---

## 6. 失敗處理通則

依 §0.7「失敗時優先自救」— 公司沒 IT，AI 把自救跑完才回報 ark0720。每個錯誤都附「AI 自救步驟」與「何時才回報 ark0720」：

| 錯誤類型 | AI 自救步驟 | 何時回報 ark0720 |
|---|---|---|
| **網路 timeout** | (1) 重試 1 次 (2) `Test-NetConnection {host} -Port 443` 看是不是 TLS 死 (3) 檢查 `netsh winhttp show proxy` / `$env:HTTPS_PROXY` (4) 有 VPN 試 disconnect/reconnect | 上述全試完仍連不上 → firewall 硬擋，回報 |
| **winget 抓不到 package** | (1) `winget source reset --force` (2) `winget source update` (3) fallback 到 `fallback_url`（`manifest/common.json`）手動下載 | 連 fallback_url 也下載不到 → 回報 |
| **權限不足** | AI 用 `Start-Process powershell -Verb RunAs` 開系統管理員 PowerShell 重跑該指令 | UAC 直接被 group policy 擋 → 回報 |
| **`git clone` 失敗（步驟 7）** | 同步驟 7 fallback：postBuffer 調大、sslVerify 排除、DNS / proxy 診斷 | 自救都跑完 → 回報（多半要開 firewall 白名單） |
| **`gws auth login --scopes ...` 失敗** | (1) 檢查 `~/.config/gws/client_secret.json` 是否存在且為合法 JSON (2) Google 回 `invalid_scope` → 某個 scope 對第三方 OAuth client 不開放（如 `keep`），依本 INSTALL.md step 9 的 14 個 scope 重跑（已剔除已知壞的）(3) `gws auth logout` 後重試 (4) 確認用 dollbao.com.tw 帳號授權 (5) 跑完後用 `gws auth status --format json` 看 `scope_count` 是否 ≥ 14 + 含 `https://mail.google.com/` | OAuth 一直被 Google 拒（client 被吊銷？）→ 回報 |
| **step 8.5 `PERMISSION_DENIED`** | (1) `gcloud auth list` 看當前帳號 (2) 非 dollbao.com.tw → `gcloud auth login` 換帳號 (3) 已是 dollbao.com.tw → 重試一次 `gcloud secrets versions access` | 重試仍失敗 → 回報 ark0720 確認該帳號在 `_HQ@dollbao.com.tw` 群組內（不要叫 user 跑 `gcloud secrets list`，secretAccessor 沒給 list 權限） |
| **step 8.5 `NOT_FOUND`** | `gcloud secrets list --project=dollbao-gws-cli --filter="name~gws-oauth-client"` 確認 secret 真的不存在 | 確認不存在 → 回報「請在 `dollbao-gws-cli` 建 secret，步驟見 `config/README.md`」 |
| **step 5.5 用錯帳號** | AI 直接跑 `gcloud auth revoke --all` 後重做 step 5.5 | 不需回報 |
| **`npm install` 失敗** | (1) 確認 Node 真的裝起來 (2) `npm cache clean --force` (3) 設 `npm config set registry https://registry.npmjs.org/` (4) 管理員 PowerShell 重試 (5) 從 GitHub release 下載 binary | release 頁也連不上 → 網路硬擋，回報 |
| **步驟 10 hash mismatch** | AI 直接跑 `scripts/helpers/generate-skills-lock.ps1` 重生 lock，再跑一次 install-gws-bundle.ps1 | 連續兩次仍 mismatch → 回報（上游可能改 schema） |
| **`bq query` 失敗（IAM）** | (1) `gcloud auth list` 確認用 dollbao.com.tw (2) `bq ls dollbao-data-center` 看自己有無 BQ 讀權限 (3) 試另一個全員 view 例如 `data-for-all-496615` | 確認帳號正確但所有 BQ 都讀不到 → 回報，需加進 BQ 全員群組 |
| **Windows 太舊（< 17763）** | 引導 user 跑 Windows Update 自動升級，三輪未動才放棄 | 物理升不上去 → 回報（可能要重灌系統） |
| **winget 不存在** | (1) `Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe` (2) 下載 .msixbundle from `https://aka.ms/getwinget` 並 `Add-AppxPackage` | 兩種方法都失敗（罕見）→ 回報 |

詳細案例見 [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)（M2-M4 累積）。

---

## 7. 部門判定 hook（Phase 2 預留）

⏸️ Phase 1 **跳過此步驟**。

Phase 2 上線時，本節會啟用：在步驟 11 後，AI 問用戶「你屬於哪個部門？」對應到 `manifest/dept-*.json` 並補裝該部門包。
