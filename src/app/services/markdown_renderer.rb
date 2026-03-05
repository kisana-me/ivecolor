require "rouge/plugins/redcarpet"
require "digest"
require "json"
require "yaml"

class MarkdownRenderer
  class CustomHTML < Redcarpet::Render::HTML
    include Rouge::Plugins::Redcarpet

    def preprocess(text)
      text = text.to_s

      # support embedding a mini post preview using ?[post](name_id)
      text = text.gsub(/\?\[post\]\(([a-zA-Z0-9\-_]+)\)/) do
        post = Post.from_normal_accounts.is_opened.find_by(name_id: ::Regexp.last_match(1).split("/").last)
        if post
          ApplicationController.renderer.render(
            "posts/_show_mini",
            locals: { post: post },
            layout: false
          ).delete("\n\r\t")
        else
          "[存在しない記事]"
        end
      end

      # support embedding X (Twitter) using ?[x](tweet_id)
      text = text.gsub(/\?\[x\]\(([a-zA-Z0-9_]+)\)/) do
        tweet_id = ::Regexp.last_match(1)
        # Using the standard widget HTML for X (with max-width for responsive fit)
        <<~HTML.strip.delete("\n\r\t")
          <div class="embed-container" data-controller="x-embed">
            <div class="embed-loader" data-x-embed-target="loader">
              <div class="embed-spinner"></div>
              <span>Xの投稿を準備中...</span>
            </div>
            <blockquote class="twitter-tweet" data-dnt="true" style="max-width: 550px; margin: 0 auto;">
              <a href="https://twitter.com/i/status/#{tweet_id}"></a>
            </blockquote>
          </div>
        HTML
      end

      # support embedding TikTok using ?[tiktok](video_id)
      text = text.gsub(/\?\[tiktok\]\(([0-9]+)\)/) do
        video_id = ::Regexp.last_match(1)
        <<~HTML.strip.delete("\n\r\t")
          <div class="embed-container" data-controller="tiktok-embed">
            <div class="embed-loader" data-tiktok-embed-target="loader">
              <div class="embed-spinner"></div>
              <span>TikTokの投稿を準備中...</span>
            </div>
            <blockquote class="tiktok-embed" cite="https://www.tiktok.com/@user/video/#{video_id}" data-video-id="#{video_id}" style="width: 100%; max-width: 325px; margin: 0 auto;">
              <section></section>
            </blockquote>
          </div>
        HTML
      end

      # support embedding Instagram using ?[ig](shortcode)
      text = text.gsub(/\?\[ig\]\(([a-zA-Z0-9_\-]+)\)/) do
        shortcode = ::Regexp.last_match(1)
        <<~HTML.strip.delete("\n\r\t")
          <div class="embed-container" data-controller="ig-embed">
            <div class="embed-loader" data-ig-embed-target="loader">
              <div class="embed-spinner"></div>
              <span>Instagramの投稿を準備中...</span>
            </div>
            <blockquote class="instagram-media" data-instgrm-permalink="https://www.instagram.com/p/#{shortcode}/" data-instgrm-version="14" style="background:#FFF; border:0; margin: 0 auto; max-width:540px; min-width:326px; padding:0; width:100%;">
            </blockquote>
          </div>
        HTML
      end

      # support embedding YouTube using ?[youtube](video_id)
      text = text.gsub(/\?\[youtube\]\(([a-zA-Z0-9_\-]+)\)/) do
        video_id = ::Regexp.last_match(1)
        <<~HTML.strip.delete("\n\r\t")
          <div class="embed-container" data-controller="youtube-embed">
            <div class="embed-loader" data-youtube-embed-target="loader">
              <div class="embed-spinner"></div>
              <span>YouTubeの動画を準備中...</span>
            </div>
            <div class="youtube-embed-frame">
              <iframe src="https://www.youtube.com/embed/#{video_id}" data-youtube-embed-target="iframe" frameborder="0" allowfullscreen allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"></iframe>
            </div>
          </div>
        HTML
      end

      # support embedding an image (single or multiple) using ?[image](aid|caption, aid2|caption2)
      # - each item: aid or aid|caption
      # - multiple items: separated by comma
      # produces <figure> with an <a><img></a> and <figcaption>, or a wrapper div.markdown-image-slider
      text = text.gsub(/\?\[image\]\(([^)]+)\)/) do
        raw = ::Regexp.last_match(1).to_s
        # split on comma to allow multiple images; captions use '|' to separate
        items = raw.split(",").map(&:strip).reject(&:empty?)

        aids = items.map { |item| item.split("|", 2).first.to_s.strip }
        images = Image.from_normal_accounts.is_normal.where(aid: aids).index_by(&:aid)

        figures = items.map do |item|
          aid, caption = item.split("|", 2).map { |s| s.to_s.strip }
          image = images[aid]
          if image
            # The following line seems to have no effect, you might want to review it.
            Rails.application.routes.url_helpers.image_path(image.aid)
            img_tag = ApplicationController.helpers.image_tag(image.image_url(variant_type: "normal"), alt: image.name)
            # build figcaption only when caption present
            figcap = ApplicationController.helpers.content_tag(:figcaption, caption.present? ? caption : image.name)

            # figure contains anchor wrapping image, and optional figcaption
            ApplicationController.helpers.content_tag(:figure, img_tag + figcap,
                                                      class: "markdown-image-figure").delete("\n\r\t")
          else
            ApplicationController.helpers.content_tag(:figure, "[存在しない画像]", class: "markdown-image-figure")
          end
        end

        if figures.size > 1
          # wrap multiple figures in a slider container; front-end can style .markdown-image-slider for horizontal sliding
          ApplicationController.helpers.content_tag(:div, figures.join.html_safe,
                                                    class: "markdown-image-slider").delete("\n\r\t")
        else
          figures.first.to_s
        end
      end

      return text if Thread.current[:markdown_renderer_skip_yt_sync]

      # support embedding a YouTube player with time-synced content using fenced block
      #
      # ```yt-sync
      # id: 9qkpcLK422o
      # cues:
      #   - at: 0
      #     content: |
      #       # hello
      #   - at: "01:20"
      #     content: |
      #       more...
      # ```
      text = text.gsub(/```yt-sync\s*\r?\n(.*?)\r?\n```/m) do
        raw = ::Regexp.last_match(1).to_s

        begin
          data = YAML.safe_load(raw, permitted_classes: [], permitted_symbols: [], aliases: false) || {}

          video_id = data["id"] || data[:id]
          cues = data["cues"] || data[:cues] || []

          raise "missing id" if video_id.to_s.strip.empty?
          raise "cues must be an array" unless cues.is_a?(Array)

          normalized_cues = cues.filter_map do |cue|
            next unless cue.is_a?(Hash)

            at_raw = cue["at"] || cue[:at]
            content_md = cue["content"] || cue[:content]
            at = parse_yt_sync_time(at_raw)
            next if at.nil?

            content_html = ::MarkdownRenderer.render(content_md.to_s, safe_render: false, skip_yt_sync: true).to_s
            { at: at, html: content_html }
          end

          normalized_cues.sort_by! { |c| c[:at] }
          cues_json = normalized_cues.map { |c| { at: c[:at] } }.to_json

          helpers = ApplicationController.helpers
          inner = helpers.content_tag(:div, class: "yt-sync-inner") do
            yt_logo_svg = <<~SVG.strip.html_safe
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" aria-hidden="true">
                <path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814z" fill="#FF0000"/>
                <path d="M9.545 15.568L15.818 12l-6.273-3.568v7.136z" fill="#FFFFFF"/>
              </svg>
            SVG
            header_content = yt_logo_svg + helpers.content_tag(:span, "YouTube Sync", class: "yt-sync-header-text")

            player_container = helpers.content_tag(:div, class: "yt-sync-main") do
              helpers.content_tag(:div, "", class: "yt-sync-player", data: { yt_sync_target: "player" })
            end

            cue_divs = normalized_cues.each_with_index.map do |cue, i|
              helpers.content_tag(
                :div,
                cue[:html].html_safe,
                class: "yt-sync-cue#{i == 0 ? '' : ' yt-sync-cue--hidden'}",
                data: { yt_sync_target: "cue" }
              )
            end.join.html_safe

            helpers.content_tag(:div, header_content, class: "yt-sync-header") +
              player_container +
              helpers.content_tag(:div, cue_divs, class: "yt-sync-content", data: { yt_sync_target: "content" })
          end
          helpers.content_tag(:div, inner,
                              class: "yt-sync",
                              data: {
                                controller: "yt-sync",
                                yt_sync_video_id_value: video_id.to_s,
                                yt_sync_cues_value: cues_json
                              }).delete("\n\r\t")
        rescue StandardError => e
          Rails.logger.warn("yt-sync parse error: #{e.class}: #{e.message}")
          ApplicationController.helpers.content_tag(:div, "[yt-sync 設定エラー]", class: "yt-sync-error")
        end
      end

      text
    end

    private

    def parse_yt_sync_time(value)
      return nil if value.nil?

      if value.is_a?(Numeric)
        return value.to_f
      end

      s = value.to_s.strip
      return nil if s.empty?
      return s.to_f if s.match?(/\A\d+(?:\.\d+)?\z/)

      if (m = s.match(/\A(?:(\d+):)?(\d{1,2}):(\d{2})\z/))
        h = m[1].to_i
        mm = m[2].to_i
        ss = m[3].to_i
        return (h * 3600) + (mm * 60) + ss
      end

      nil
    end
  end

  def self.render(markdown_text, safe_render: false, skip_yt_sync: false)
    text = markdown_text.to_s
    digest = Digest::SHA256.hexdigest(text)
    cache_key = [
      "markdown_renderer",
      "v2",
      safe_render ? "safe1" : "safe0",
      skip_yt_sync ? "ytskip1" : "ytskip0",
      digest
    ].join(":")

    html = Rails.cache.fetch(cache_key) do
      previous_skip = Thread.current[:markdown_renderer_skip_yt_sync]
      Thread.current[:markdown_renderer_skip_yt_sync] = skip_yt_sync

      options = {
        hard_wrap: true,
        with_toc_data: true,
        filter_html: safe_render
      }
      extensions = {
        tables: true,
        fenced_code_blocks: true,
        disable_indented_code_blocks: true,
        autolink: true,
        strikethrough: true,
        lax_spacing: true,
        space_after_headers: true,
        superscript: true,
        underline: true,
        highlight: true,
        quote: true,
        footnotes: true
      }
      renderer = CustomHTML.new(options)
      markdown = Redcarpet::Markdown.new(renderer, extensions)
      markdown.render(text)
    ensure
      Thread.current[:markdown_renderer_skip_yt_sync] = previous_skip
    end

    html.to_s.html_safe
  end

  def self.render_toc(markdown_text)
    renderer = Redcarpet::Render::HTML_TOC.new(nesting_level: 6)
    markdown = Redcarpet::Markdown.new(renderer, space_after_headers: true)
    markdown.render(markdown_text || "").html_safe
  end

  def self.render_plain(markdown_text)
    html = render(markdown_text)
    ApplicationController.helpers.strip_tags(html)
  end
end
