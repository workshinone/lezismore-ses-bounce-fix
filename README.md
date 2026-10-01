# lezismore-ses-bounce-fix

Discourse 小外掛：讓 Amazon SES 經 SNS 送來的退信通知能對上 `email_logs`。

## 為什麼需要
核心 `Jobs::ProcessSnsNotification`（2026-06-30 `61f12e1` 之後）用 SES 的 `mail.messageId` 比對 Discourse 的 RFC `Message-ID`，兩者不同 → 退信靜默略過。上游回報：<https://meta.discourse.org/t/411536>。

## 前提
SES identity 的 Bounce notification 必須開 **Include original email headers**，SNS 通知才帶 `mail.commonHeaders.messageId`。

## 安裝（併入下次 rebuild）
`/var/discourse/containers/app.yml` 的 `hooks: after_code: - exec: cmd:` 清單加一行：
```yaml
- git clone https://github.com/workshinone/lezismore-ses-bounce-fix.git
```
然後 `./launcher rebuild app`。

## 驗證
rebuild 後等下一封真實退信：
```sql
SELECT created_at, to_address, bounced, bounce_error_code FROM email_logs
WHERE bounced ORDER BY created_at DESC LIMIT 5;
SELECT u.username, s.bounce_score FROM user_stats s JOIN users u ON u.id=s.user_id WHERE s.bounce_score > 0;
```
看到 `bounced=true`、`bounce_score` 開始累加（soft bounce 每次 +1，達 4 停寄）＝成功。
`/logs` 若出現 `lezismore-ses-bounce-fix:` 開頭的 warn，代表 payload 形狀出乎意料，核心邏輯仍照舊執行。

## 移除
上游修復後，從 app.yml 拿掉那一行、rebuild。
