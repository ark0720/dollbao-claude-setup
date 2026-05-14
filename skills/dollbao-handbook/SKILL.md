---
name: dollbao-handbook
description: ⏸️ M3 placeholder。逗寶人規章查詢（含人事、財務計畫、雲端硬碟使用規則、共用圖檔規則等全公司規章）。當使用者問到請假、加班、考核、福利、財務流程、Drive 使用、圖檔上傳、命名規則等公司內部規章相關問題時觸發。
---

# ⏸️ M3 placeholder — dollbao-handbook

本 skill 為「兩層索引型」（見 [`../../docs/MAINTAINER.md` §2b](../../docs/MAINTAINER.md)）。M3 階段填完以下章節：

## 觸發時機（M3 完稿）

任何涉及公司規章 / 內部 SOP 的問題：
- 人事：請假、加班、考核、福利、薪資、年資
- 財務：費用報銷、財務計畫
- 雲端硬碟：使用規則、檔案命名、共用圖檔位置
- 其他全公司 SOP

## 怎麼回答

1. **先看 skill body 的 digest（下方）**，找最符合提問的 1-3 份 Doc
2. 若 digest 沒覆蓋，再用 `gws-sheets-read` 讀規章索引 spreadsheet：
   `1zz19TNY_EfHxAbwEgTJqdJgJbGeH51K71RcBz-JVEMY`
3. 用 `gws-docs` 讀對應 Doc 拿完整內容
4. 引用具體章節並附 Doc 連結，**不要憑空回答**

## 規章 digest

<!-- digest-start -->
⏸️ **M2.5 階段由獨立 session 預先產生。**

預期格式（每份規章 Doc 一個區塊）：

```
### {規章名稱}（Doc ID `xxx`）
**涵蓋：** {2-3 句摘要}
**關鍵詞：** 詞1、詞2、詞3...
**何時用：** {觸發情境描述}
```

digest 同步 SOP 見 [`../../docs/MAINTAINER.md` §6](../../docs/MAINTAINER.md)。
<!-- digest-end -->

## 引用格式

回答時請以以下格式附來源：

> 依據《{規章名稱}》第 X 條／第 X 節：{內容}
> 完整文件：{Doc URL}
