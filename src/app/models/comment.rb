class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :account, optional: true
  belongs_to :comment, optional: true
  has_many :comments

  attribute :meta, :json, default: -> { {} }
  enum :visibility, { closed: 0, limited: 1, opened: 2 }
  enum :status, { normal: 0, locked: 1, deleted: 2 }
  attr_accessor :post_aid, :replied_aid

  before_validation :assign_post
  before_validation :assign_comment
  before_create :set_aid

  validates :content,
            presence: true,
            length: { in: 1..1000, allow_blank: true }

  scope :from_normal_accounts, -> { left_joins(:account).where(accounts: { status: :normal }).or(where(account: nil)) }
  scope :is_normal, -> { where(status: :normal) }
  scope :isnt_deleted, -> { where.not(status: :deleted) }
  scope :is_opened, -> { where(visibility: :opened) }
  scope :isnt_closed, -> { where.not(visibility: :closed) }

  private

  def assign_post
    return if post_aid.blank? || self.post.present?

    self.post = Post.find_by(aid: post_aid)
  end

  def assign_comment
    return if replied_aid.blank? || self.comment.present?

    replied_comment = Comment.find_by(aid: replied_aid)
    if replied_comment.nil? || replied_comment.comment.present?
      errors.add(:base, "返信先のコメントが見つかりませんでした")
      return
    end

    self.comment = replied_comment
  end
end
