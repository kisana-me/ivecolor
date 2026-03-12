class CommentsController < ApplicationController
  before_action :require_signin, only: %i[update]
  before_action :set_comment, only: %i[update]

  def create
    @comment = Comment.new(comment_params)

    unless verify_turnstile(params["cf-turnstile-response"])
      # @comment.errors.add(:base, :failed_captcha)
      flash[:alert] = "botでないことを証明してください"
      redirect_to post_path(params[:comment][:post_aid])
      return
    end

    post = Post.find_by(aid: params[:comment][:post_aid])
    if params[:comment][:replied].present?
      comment = Comment.find_by(aid: params[:comment][:replied])
      @comment.comment = comment if comment.comment.nil?
    end
    @comment.account = @current_account
    @comment.post = post
    if @comment.save
      flash[:notice] = "コメントを書き込みました"
    else
      flash[:alert] = "エラー:#{@comment.errors.full_messages.join(', ')}"
    end
    redirect_to post_path(post.name_id)
  end

  def update
    if @comment.update(update_comment_params)
      flash[:notice] = "コメントを更新しました"
    else
      flash[:alert] = "エラー:#{@comment.errors.full_messages.join(', ')}"
    end
    redirect_to post_path(@comment.post.name_id)
  end

  private

  def comment_params
    params.expect(
      comment: %i[
        name
        content
        address
      ]
    )
  end

  def update_comment_params
    params.expect(
      comment: [:visibility]
    )
  end

  def set_comment
    @comment = Comment.find_by(aid: params[:aid])
  end
end
