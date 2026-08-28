require "fileutils"
require "json"

# アカウント1件を JSON にする。
#
# アイコンの実体は落とさない（AllExporter の頭を参照）。移行先の
# accounts.icon_media_id に入れる **画像の aid だけ** を出す。
class AccountExporter
  def initialize(account, root: Rails.root.join("storage"))
    @account = account
    @dir = Pathname.new(root).join("accounts", account.aid)
  end

  def call
    FileUtils.mkdir_p(@dir)

    data = {
      aid: @account.aid,
      name: @account.name,
      name_id: @account.name_id,
      description: @account.description,
      icon_aid: @account.icon&.aid,
      visibility: @account.visibility,
      status: @account.status,
      meta: @account.meta,
      created_at: iso(@account.created_at),
      updated_at: iso(@account.updated_at)
    }

    File.write(@dir.join("account.json"), JSON.pretty_generate(data))
    data
  end

  private

  def iso(time)
    time&.utc&.iso8601(3)
  end
end
