# config/ — 公司層級設定（Secret Manager 流程）

這個資料夾**不再放 OAuth credentials 本體**。改用 Google Cloud Secret Manager
儲存，repo 公開後不會 leak。新人本機透過 `gcloud secrets versions access`
拉取。

---

## 為什麼從 placeholder JSON 改成 Secret Manager？

M2.6 原本設計：repo 內放 `gws-client-secret.json` placeholder，ark0720 填真值後 commit。

M2.7 改用 Secret Manager 原因：
- repo 已翻 public（M2.5），把真實 OAuth client_id + client_secret 推進 public repo 有 phishing 風險（外人能以「dollbao 內部工具」名義對員工發起假 OAuth 流程）
- Google Cloud Secret Manager 是 GCP 內建服務，IAM 控管 + 加密儲存 + 有免費 tier
- 員工本機透過 `gcloud auth login` 後就能讀（已是 BigQuery skill 必要前置）

---

## ark0720 一次性設定流程

### 一、GCP 專案準備（已完成）

- 專案：`dollbao-gws-cli`
- Workspace domain：`dollbao.com.tw`

### 二、啟用 API（已完成或 M2.7 補上）

依 `docs/INSTALL.md` 或 `_SESSION_BOOTSTRAP.md` 列表，至少要啟用：
- Workspace API：Gmail / Calendar / Drive / Docs / Sheets / Chat / Tasks / Forms / Slides / People / Keep / Meet / Classroom / Apps Script / Admin Reports
- Workspace Events、Model Armor
- **Secret Manager**（本流程必須）
- BigQuery（M3 dollbao-calendar 用）

### 三、OAuth Client ID（GCP Console，~10 分鐘）

1. 開 https://console.cloud.google.com/apis/credentials?project=dollbao-gws-cli
2. **OAuth consent screen** → User type **Internal**
   - App name: `逗寶內部工具` 或 `DollBao Internal Tools`
   - User support email / Developer contact: `ark@dollbao.com.tw`
3. **Credentials** → CREATE CREDENTIALS → **OAuth client ID**
   - Application type: **Desktop app**
   - Name: `dollbao-claude-setup gws CLI`
   - **DOWNLOAD JSON**（暫存到 ~/Downloads/）

### 四、上傳到 Secret Manager + 授權 domain（PowerShell）

```powershell
$jsonFile = Get-ChildItem "$HOME\Downloads\client_secret_*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

gcloud secrets create gws-oauth-client `
  --project=dollbao-gws-cli `
  --replication-policy=automatic

gcloud secrets versions add gws-oauth-client `
  --data-file=$jsonFile.FullName `
  --project=dollbao-gws-cli

# ── Secret 層：誰能讀 gws-oauth-client 內容 ──

# 主路徑：整個 Workspace domain
# 前提：dollbao.com.tw 已是 GCP Organization 的 directory domain（dollbao 早就有 org
# id=227160356082，customer C016v613l），所以 domain: binding 直接生效，不需要再額外驗證。
gcloud secrets add-iam-policy-binding gws-oauth-client `
  --member="domain:dollbao.com.tw" `
  --role="roles/secretmanager.secretAccessor" `
  --project=dollbao-gws-cli

# 備援 binding：_HQ 群組
# 留著當保險絲（萬一未來 domain binding 被誤刪、或某員工不在 dollbao.com.tw domain 但有
# _HQ 個人成員資格），但**不要靠它**。原因：_HQ 在逗寶是 nested distribution group（裡面
# 裝子群組裝子群組），Cloud IAM 對 group: binding **只認 direct member，不認 transitive
# nested member**，所以 _HQ binding 實際只對 _HQ 的兩個個人帳號（ark@、qb@）生效，全公
# 司絕大多數員工拿不到。
gcloud secrets add-iam-policy-binding gws-oauth-client `
  --member="group:_HQ@dollbao.com.tw" `
  --role="roles/secretmanager.secretAccessor" `
  --project=dollbao-gws-cli

# ── Project 層：誰能對 dollbao-gws-cli 發 API request ──
# CRITICAL：光給 secretAccessor 不夠！Google Cloud 的 API 呼叫要過兩道閘：
#   閘 1（Project 層）：能不能對 dollbao-gws-cli 發 Secret Manager API request？
#                       需 roles/serviceusage.serviceUsageConsumer
#   閘 2（Secret 層）：能不能讀 gws-oauth-client 這個 secret？
#                      需 roles/secretmanager.secretAccessor（上面已給）
# Project owner（ark0720）自動有閘 1 權限所以跑得通，但員工沒有 → 卡在閘 1
# 連發 request 都被擋。下面這條補上閘 1。
gcloud projects add-iam-policy-binding dollbao-gws-cli `
  --member="domain:dollbao.com.tw" `
  --role="roles/serviceusage.serviceUsageConsumer"

# 備援 project-level binding：_HQ（同上備援，不要靠它）
gcloud projects add-iam-policy-binding dollbao-gws-cli `
  --member="group:_HQ@dollbao.com.tw" `
  --role="roles/serviceusage.serviceUsageConsumer"
```

> **歷史踩過的坑（三次，紀錄完整給未來的 ark0720）：**
>
> 1. **第一次（誤判 domain 沒生效）：** 一開始只設 `domain:dollbao.com.tw` 的 secret-level `secretAccessor`，職員跑 step 8.5 全部 `PERMISSION_DENIED`。**當時誤以為**是 domain 沒做 Cloud Identity 驗證，改用 `group:_HQ@dollbao.com.tw`。其實 dollbao 早就有 GCP organization、domain 早就驗證完成 — 問題從來不在 domain binding 本身，而是缺 project 層的 `serviceUsageConsumer`（見第三次）。
>
> 2. **第二次（發現兩道閘）：** 加了 `_HQ` group 的 `secretAccessor` 後職員仍 `PERMISSION_DENIED`。發現原因：Google Cloud API 呼叫要過兩道閘，光資源層 (`secretAccessor`) 不夠，還要 project 層 (`serviceUsageConsumer`)。補上 `_HQ` 的 project-level `serviceUsageConsumer`。Owner（ark0720）自動有閘 1 所以自己測不出來。
>
> 3. **第三次（發現 nested group 不認 transitive）：** 即使 `_HQ` 兩道閘都齊了，員工 jessical 仍 `PERMISSION_DENIED`。查 `_HQ` 群組成員，發現裡面全是子群組（`_div1` / `_dept5B` / `_HQ` 等 17 個）+ 2 個個人帳號（ark@、qb@）。**Google Cloud IAM 對 `group:` binding 只認 direct member，不認 transitive / nested group**，所以 `_HQ` binding 對「子群組底下的員工」完全無效。最終解：用 `domain:dollbao.com.tw` binding（兩道閘都用 domain），_HQ binding 降為保險絲。
>
> **未來通則（GCP IAM checklist）：**
> - **兩道閘原則：** 給員工任何 GCP 資源權限，資源層角色（`secretAccessor` / `dataViewer` / 等）+ project 層 `serviceUsageConsumer` **兩個都要給**
> - **群組原則：** 用 `domain:dollbao.com.tw` 當主要 binding（dollbao 已驗證），別靠 `group:_HQ`（nested 限制）。除非用「直接成員都是個人帳號」的 flat group
> - **驗證原則：** 改完 IAM 別只靠 owner 帳號測，要用一個透過子群組進來的真實員工帳號（如 jessical）測一次才算數

### 五、清理 + 驗證

```powershell
# 把下載的本機 JSON 刪掉（內容已進 Secret Manager）
Remove-Item $jsonFile.FullName

# 驗證 ark0720 自己讀得到
gcloud secrets versions access latest --secret=gws-oauth-client --project=dollbao-gws-cli | Select-Object -First 3
```

---

## 新人本機怎麼用（自動，由 install.md step 8.5 處理）

```powershell
# 前置：step 5.5 已跑過 gcloud auth login（用公司 dollbao.com.tw 帳號）
$gwsCfg = Join-Path $env:USERPROFILE ".config\gws"
New-Item -ItemType Directory -Force -Path $gwsCfg | Out-Null

gcloud secrets versions access latest `
  --secret=gws-oauth-client `
  --project=dollbao-gws-cli `
  > (Join-Path $gwsCfg "client_secret.json")
```

新人本機 `~/.config/gws/client_secret.json` 是從 Secret Manager 拉的副本，
不在 repo 內，外人就算 fork repo 也拿不到。

---

## 未來想換 secret / rotate

```powershell
# 在 GCP Console 重新建一組新的 OAuth client → download JSON → 跑：
gcloud secrets versions add gws-oauth-client --data-file=新檔.json --project=dollbao-gws-cli
```

舊版本自動 disable，新 version 自動成為 `latest`。新人下次重跑 step 8.5 即抓到新版。
