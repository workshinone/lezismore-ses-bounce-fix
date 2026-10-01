# frozen_string_literal: true

# name: lezismore-ses-bounce-fix
# about: Match SES/SNS bounce notifications to EmailLog via the original RFC Message-ID (works around upstream bug, meta.discourse.org/t/411536)
# version: 0.1.0
# authors: Lezismore
# url: https://github.com/workshinone/lezismore-ses-bounce-fix

# 背景（2026-10-01）：核心 Jobs::ProcessSnsNotification 用 SNS 通知的 mail.messageId
# （SES 自己配的 ID）去找 EmailLog.message_id（Discourse 自己的 RFC Message-ID），
# 永遠對不上 → 退信從不被記錄、bounce_score 不累加、不會自動停寄。
# 本外掛在 job 執行前，若 SES 通知帶有原始 header（identity 需開 Include original
# headers；本站已開），就把 commonHeaders.messageId 清掉 <> 後塞回 mail.messageId，
# 其餘（TopicArn 白名單、SNS 簽章驗證、去重）全交回核心。上游修好即可移除。

after_initialize do
  module ::LezismoreSesBounceFix
    def execute(args)
      begin
        json = args[:json]
        if json.is_a?(Hash) && json["Message"].present?
          message =
            begin
              JSON.parse(json["Message"])
            rescue JSON::ParserError
              nil
            end
          rfc = message&.dig("mail", "commonHeaders", "messageId")
          if rfc.present?
            cleaned = Email::MessageIdService.message_id_clean(rfc.to_s.strip)
            if cleaned.present? && EmailLog.exists?(message_id: cleaned)
              message["mail"]["messageId"] = cleaned
              args = args.merge("json" => json.merge("Message" => message.to_json))
            end
          end
        end
      rescue => e
        Rails.logger.warn("lezismore-ses-bounce-fix: #{e.class}: #{e.message}")
      end
      super(args)
    end
  end

  ::Jobs::ProcessSnsNotification.prepend ::LezismoreSesBounceFix
end
