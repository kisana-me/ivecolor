class CommentsController < ApplicationController
  before_action :require_signin, only: %i[update]
  before_action :set_comment, only: %i[update]

  def create
    @comment = Comment.new(comment_params)

    @target_dom_id = "comment-form"
    if @comment.replied_aid.present?
      @target_dom_id += "-#{@comment.replied_aid}"
    end

    unless verify_turnstile(params["cf-turnstile-response"])
      @comment.errors.add(:base, "botでないことを証明してください")
      return render_error()
    end

    if @comment.save
      flash.now[:notice] = "コメントを投稿しました"
      render :create, formats: :turbo_stream
    else
      render_error()
    end
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
        post_aid
        replied_aid
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

  def render_error()
    flash.now[:alert] = "コメントを投稿できませんでした"
    locals = {
      comment: @comment,
      url: comments_path,
      post_aid: @comment.post_aid
    }
    locals[:initial_replied] = @comment.replied_aid if @comment.replied_aid.present?
    render turbo_stream: [
      turbo_stream.replace(
        @target_dom_id,
        partial: "form",
        locals: locals
      ),
      turbo_stream.update("flash", partial: "shared/flash")
    ], status: :unprocessable_entity
  end
end
