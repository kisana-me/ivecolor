# 旧サイト（この Rails アプリ）のデータを、headless-cms の移行スクリプト
# （kisana-me/headless-cms の tools/migrate/migrate.mjs）が読む形で吐く。
#
#   bin/rails runner 'AllExporter.new.call'
#
# **画像の実体はここでは落とさない。** MinIO のバケットを丸ごと持っていって
# migrate.mjs に --media で渡す（headless-cms docs/design.md 9章）。1枚ずつ
# get_object するより速く、本文の記法にも左右されない。ここが吐くのは
# 「どの aid の画像が、どの variant を持っているか」という対応だけ。
#
# 出力（Rails.root/storage 以下）
#   accounts/accounts.json      aid の配列
#   accounts/{aid}/account.json
#   tags/tags.json
#   images/images.json
#   posts/posts.json            aid の配列
#   posts/{aid}/data.json
#   posts/{aid}/post.md         本文そのまま（記法変換は migrate.mjs の仕事）
#   posts/{aid}/comments.json
#   report.json                 件数と、拾えなかったもの
class AllExporter
  # 移行先が要求するのは normal だけ（headless-cms docs/design.md 9.1）
  MIGRATION_VARIANT = "normal".freeze

  # @param root [Pathname] 出力先
  # @param prepare_variants [Boolean] 出力前に normal variant を作る。
  #   image_url が variant を遅延生成する作りなので、一度も表示されていない画像は
  #   MinIO に normal が存在しない。移行前に一度だけ true で回す
  def initialize(root: Rails.root.join("storage"), prepare_variants: false)
    @root = Pathname.new(root)
    @prepare_variants = prepare_variants
    @report = { exported_at: nil, counts: {}, warnings: [] }
  end

  def call
    FileUtils.mkdir_p(@root)
    prepare_variants! if @prepare_variants

    export_accounts
    export_tags
    export_posts
    export_images

    @report[:exported_at] = Time.current.utc.iso8601(3)
    write_json(@root.join("report.json"), @report)
    @report
  end

  private

  def warn!(message)
    Rails.logger.warn("[AllExporter] #{message}")
    @report[:warnings] << message
  end

  def write_json(path, data)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, JSON.pretty_generate(data))
  end

  # 変換済みの normal を全画像に用意する。**これをやらないと移行で画像が欠ける。**
  # 元画像を消してある画像（original_ext が空）は作れないので、名指しで報告する
  def prepare_variants!
    made = 0
    Image.find_each do |image|
      next if image.variants.include?(MIGRATION_VARIANT)

      if image.original_ext.blank?
        warn!("画像 #{image.aid} は原本が無いので #{MIGRATION_VARIANT} を作れません")
        next
      end

      begin
        image.process_image(variant_type: MIGRATION_VARIANT)
        made += 1
      rescue StandardError => e
        warn!("画像 #{image.aid} の #{MIGRATION_VARIANT} 生成に失敗: #{e.message}")
      end
    end
    @report[:counts][:variants_generated] = made
  end

  def export_accounts
    dir = @root.join("accounts")
    FileUtils.mkdir_p(dir)
    write_json(dir.join("accounts.json"), Account.order(:created_at).pluck(:aid))

    count = 0
    Account.includes(:icon).find_each do |account|
      AccountExporter.new(account, root: @root).call
      count += 1
    end
    @report[:counts][:accounts] = count
  end

  def export_tags
    @report[:counts][:tags] = TagsExporter.new(root: @root).call.size
  end

  def export_posts
    dir = @root.join("posts")
    FileUtils.mkdir_p(dir)
    write_json(dir.join("posts.json"), Post.order(:created_at).pluck(:aid))

    count = 0
    comments = 0
    Post.includes(:account, :thumbnail, :tags).find_each do |post|
      comments += PostExporter.new(post, root: @root).call
      count += 1
    end
    @report[:counts][:posts] = count
    @report[:counts][:comments] = comments
  end

  def export_images
    images = ImagesExporter.new(root: @root).call
    @report[:counts][:images] = images.size
    missing = images.count { |i| i[:variants].exclude?(MIGRATION_VARIANT) }
    return if missing.zero?

    warn!(
      "#{missing}件の画像に #{MIGRATION_VARIANT} variant がありません。" \
      "AllExporter.new(prepare_variants: true).call で作ってから流してください"
    )
  end
end
