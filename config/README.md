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

# 主要 binding：全員 Google Group（穩，不需要 Cloud Identity 驗證）
gcloud secrets add-iam-policy-binding gws-oauth-client `
  --member="group:_HQ@dollbao.com.tw" `
  --role="roles/secretmanager.secretAccessor" `
  --project=dollbao-gws-cli

# 備援 binding：整個 Workspace domain（需要 dollbao.com.tw 在 Cloud Identity 驗證後才會生效；
# 留著當保險絲，未驗證時不會作數但也不會壞事）
gcloud secrets add-iam-policy-binding gws-oauth-client `
  --member="domain:dollbao.com.tw" `
  --role="roles/secretmanager.secretAccessor" `
  --project=dollbao-gws-cli
```

> **歷史踩過的坑：** 一開始只設 `domain:dollbao.com.tw`，職員跑 step 8.5 全部 `PERMISSION_DENIED` — `domain:` binding 必須 dollbao.com.tw 在 Google Cloud Identity 完成 domain 驗證才生效，光是 Workspace domain 不夠。改用 `group:_HQ@dollbao.com.tw`（公司既有的全員 group）就解決了。未來新員工加入 `_HQ` 群組自動有權限，離職移出群組自動失效，不用動 IAM。

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
