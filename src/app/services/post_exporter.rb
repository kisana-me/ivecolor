require "fileutils"
require "json"

# 記事1件を JSON + Markdown にする。
#
# **本文には手を入れない。** DB に入っている `?[image](aid|alt)` などの独自記法は
# そのまま出して、移行先の記法への変換は migrate.mjs（tools/migrate/notation.mjs）
# に任せる。以前ここでやっていた `:image_aid:` への置換と画像ダウンロードは
# 「保存時に標準記法→独自記法へ変換される」（Post#transform_standard2custom_image）
# ようになった時点で空振りしていたので、丸ごと外した。
#
# @return [Integer] 出したコメント数
class PostExporter
  def initialize(post, root: Rails.root.join("storage"))
    @post = post
    @dir = Pathname.new(root).join("posts", post.aid)
  end

  def call
    FileUtils.mkdir_p(@dir)

    File.write(@dir.join("post.md"), @post.content.to_s)
    File.write(@dir.join("data.json"), JSON.pretty_generate(post_data))

    comments = comments_data
    File.write(@dir.join("comments.json"), JSON.pretty_generate(comments))
    comments.size
  end

  private

  def post_data
    {
      aid: @post.aid,
      account_aid: @post.account&.aid,
      # /posts/:name_id を維持するのが移行の前提。**必ず出す**
      name_id: @post.name_id,
      title: @post.title,
      summary: @post.summary,
      content: @post.content,
      # 移行先の posts.thumbnail_id に入れる画像の aid
      thumbnail_aid: @post.thumbnail&.aid,
      # 下書きか公開かを決めるのは visibility のほう。status は種別（specific）を持つ
      visibility: @post.visibility,
      status: @post.status,
      tags: @post.tags.map(&:aid),
      meta: @post.meta,
      published_at: iso(@post.published_at),
      edited_at: iso(@post.edited_at),
      created_at: iso(@post.created_at),
      updated_at: iso(@post.updated_at)
    }
  end

  def comments_data
    @post.comments.includes(:account, :comment).order(:created_at).map do |comment|
      {
        aid: comment.aid,
        account_aid: comment.account&.aid,
        name: comment.name,
        content: comment.content,
        # 非公開の連絡先。移行先には入るが、サイトへのエクスポートには出ない
        address: comment.address,
        visibility: comment.visibility,
        status: comment.status,
        parent_comment_aid: comment.comment&.aid,
        meta: comment.meta,
        created_at: iso(comment.created_at),
        updated_at: iso(comment.updated_at)
      }
    end
  end

  def iso(time)
    time&.utc&.iso8601(3)
  end
end
