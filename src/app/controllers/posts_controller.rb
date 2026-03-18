class PostsController < ApplicationController
  include PostsHelper
  include ViewLogger

  before_action :require_signin, except: %i[index show]
  before_action :set_post, only: %i[show]
  before_action :set_correct_post, only: %i[edit update destroy]

  def index
    posts = Post
      .from_normal_accounts
      .is_normal
      .is_opened
      .order(published_at: :desc)
      .includes(:thumbnail)
    @posts = set_pagination_for(posts)
  end

  def show
    @permission = @current_account && (@current_account.id == @post.account_id || admin?)
    all_comments = @post.comments.from_normal_accounts.isnt_deleted.includes(:account).order(id: :desc)

    if @permission
      @comments = all_comments
      @views_count = ViewLog.where(viewable: @post).count
    else
      @comments = all_comments.select { |c| c.opened? }
      log_view(@post)
    end
  end

  def new
    @post = Post.new
  end

  def edit; end

  def create
    @post = Post.new(post_params)
    @post.account = @current_account
    @post.tagging
    if @post.save
      redirect_to post_path(@post.name_id), notice: "作成しました"
    else
      flash.now[:alert] = "作成できませんでした"
      render :new
    end
  end

  def update
    @post.assign_attributes(post_params)
    @post.tagging
    if @post.save
      redirect_to post_path(@post.name_id), notice: "更新しました"
    else
      flash.now[:alert] = "更新できませんでした"
      render :edit
    end
  end

  def destroy
    if @post.update(status: :deleted)
      redirect_to images_path, notice: "削除しました"
    else
      flash.now[:alert] = "削除できませんでした"
      render :edit
    end
  end

  private

  def post_params
    params.expect(
      post: [
        :name_id,
        :title,
        :summary,
        :content,
        :published_at,
        :edited_at,
        :visibility,
        :thumbnail_new_image,
        :thumbnail_image_aid,
        { selected_tags: [] }
      ]
    )
  end

  def set_post
    preload_assocs = %i[account tags images thumbnail]

    @post = Post
      .from_normal_accounts
      .is_normal
      .isnt_closed
      .includes(preload_assocs)
      .find_by(name_id: params[:name_id])
    return if @post

    return render_404 unless @current_account

    @post = @current_account.posts
      .isnt_deleted
      .includes(preload_assocs)
      .find_by(name_id: params[:name_id])
    return if @post

    @post = Post
      .unscoped
      .includes(preload_assocs)
      .find_by(name_id: params[:name_id])
    return if admin? && @post

    render_404
  end

  def set_correct_post
    return render_404 unless @current_account

    preload_assocs = %i[account tags images thumbnail]

    @post = @current_account.posts
      .isnt_deleted
      .includes(preload_assocs)
      .find_by(name_id: params[:name_id])
    return if @post

    @post = Post
      .unscoped
      .includes(preload_assocs)
      .find_by(name_id: params[:name_id])
    return if admin? && @post

    render_404
  end
end
