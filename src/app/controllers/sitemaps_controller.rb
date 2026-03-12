class SitemapsController < ApplicationController
  def index
    @posts = Post
      .from_normal_accounts
      .is_normal
      .is_opened
      .order(published_at: :desc)
  end
end
