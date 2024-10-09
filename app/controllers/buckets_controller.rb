class BucketsController < ApplicationController
  before_action :set_bucket, except: %i[ index new create ]

  def index
    @buckets = Current.user.buckets.all
  end

  def new
    @bucket = Current.account.buckets.build
  end

  def create
    @bucket = Current.account.buckets.create!(bucket_params)
    redirect_to bucket_bubbles_url(@bucket)
  end

  def edit
    selected_user_ids = @bucket.users.pluck :id
    @selected_users, @unselected_users = User.active.alphabetically.partition { |user| selected_user_ids.include? user.id }
  end

  def update
    @bucket.transaction do
      @bucket.update! bucket_params
      @bucket.accesses.revise granted: grantees, revoked: revokees
    end

    redirect_to bucket_bubbles_url(@bucket)
  end

  def destroy
    @bucket.destroy
    redirect_to buckets_url
  end

  private
    def set_bucket
      @bucket = Current.user.buckets.find params[:id]
    end

    def bucket_params
      params.require(:bucket).permit(:name)
    end

    def grantees
      Current.account.users.active.where id: grantee_ids
    end

    def revokees
      @bucket.users.where.not id: grantee_ids
    end

    def grantee_ids
      params.fetch :user_ids, []
    end
end
