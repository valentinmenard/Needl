module Api
  class UserWishlistPicturesController < ApplicationController
    acts_as_token_authentication_handler_for User
    skip_before_action :verify_authenticity_token
    skip_before_filter :authenticate_user!


    def create
      @user = User.find_by(authentication_token: params["user_token"])
      @user_wishlist = UserWishlistPicture.new
      @user_wishlist.user_id = @user.id
      @user_wishlist.picture = params["file"]
      @user_wishlist.save
      @tracker.track(@user.id, 'New Wishlist Picture', { "user" => @user.name })
      redirect_to user_path(@user.id)
    end



  end
end