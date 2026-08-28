require "fileutils"
require "json"

class TagsExporter
  def initialize(root: Rails.root.join("storage"))
    @dir = Pathname.new(root).join("tags")
  end

  def call
    FileUtils.mkdir_p(@dir)

    tags_data = Tag.order(:created_at).map do |tag|
      {
        aid: tag.aid,
        name: tag.name,
        # /tags/:name_id になる。**移行の前提なので必ず出す**
        name_id: tag.name_id,
        description: tag.description,
        visibility: tag.visibility,
        status: tag.status,
        meta: tag.meta,
        created_at: iso(tag.created_at),
        updated_at: iso(tag.updated_at)
      }
    end

    File.write(@dir.join("tags.json"), JSON.pretty_generate(tags_data))
    tags_data
  end

  private

  def iso(time)
    time&.utc&.iso8601(3)
  end
end
