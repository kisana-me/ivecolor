xml.instruct! :xml, version: "1.0", encoding: "UTF-8"

xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
  xml.url do
    xml.loc root_url
    xml.changefreq "weekly"
    xml.priority "1.0"
  end

  xml.url do
    xml.loc posts_url
    xml.changefreq "daily"
    xml.priority "0.8"
  end

  @posts.each do |post|
    xml.url do
      xml.loc post_url(post.name_id)

      target_date = post.edited_at || post.published_at || post.updated_at
      xml.lastmod target_date.strftime("%Y-%m-%dT%H:%M:%S%:z")

      xml.changefreq "weekly"
      xml.priority "0.6"
    end
  end
end
