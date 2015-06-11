module Api
  class UsersController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_filter :authenticate_user!

    def show
      @user = User.find(params["id"].to_i)
      @restaurants = Restaurant.joins(:recommendations).where(recommendations: { user_id: @user.id })
      @number = @restaurants.length
    end

  end
end