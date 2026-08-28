require "fileutils"
require "json"

# 画像のメタ情報だけを出す。**実体は MinIO のバケットから直接持っていく**
# （AllExporter の頭を参照）。
#
# MinIO 上のキーはこの2つ（app/models/concerns/image_tools.rb）。
#   images/originals/{aid}.{original_ext}
#   images/variants/{variant_type}/{aid}.webp
#
# variants は遅延生成なので、**この配列に無い variant はバケットにも無い**。
# migrate.mjs はこれを見てどのファイルを拾うかを決める。
class ImagesExporter
  def initialize(root: Rails.root.join("storage"))
    @dir = Pathname.new(root).join("images")
  end

  def call
    FileUtils.mkdir_p(@dir)

    images_data = Image.order(:created_at).map do |image|
      {
        aid: image.aid,
        account_aid: image.account&.aid,
        name: image.name,
        description: image.description,
        original_ext: image.original_ext.presence,
        variants: image.variants,
        visibility: image.visibility,
        status: image.status,
        meta: image.meta,
        created_at: iso(image.created_at),
        updated_at: iso(image.updated_at)
      }
    end

    File.write(@dir.join("images.json"), JSON.pretty_generate(images_data))
    images_data
  end

  private

  def iso(time)
    time&.utc&.iso8601(3)
  end
end
