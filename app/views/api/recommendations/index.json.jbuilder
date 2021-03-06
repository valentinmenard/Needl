json.array! @api_activities do |activity|

  if (@user.platform == "ios" && (@user.app_version == nil || @user.app_version < "2.0.3")) || (@user.platform == "android" && (@user.app_version == nil || @user.app_version < "1.0.2" ))

    if activity.trackable_type == "Recommendation"
      @restaurant_id = @all_recommendations_infos[activity.trackable_id][:restaurant_id]
    elsif activity.trackable_type == "Wish"
      @restaurant_id = @all_wishes_infos[activity.trackable_id]
    end
    if activity.owner_type == 'User'
      json.user                    @all_users_infos[activity.owner_id][:name].split(" ")[0]
    else
      json.user                    @all_users_infos[activity.owner_id][:name]
    end
    json.user_type                 activity.owner_type
    json.user_picture              @all_users_infos[activity.owner_id][:picture]
    json.user_id                   activity.owner_id
    json.restaurant_name           @all_restaurants_infos[@restaurant_id][:name]
    json.restaurant_picture        @all_restaurant_pictures_infos[@restaurant_id] ? @all_restaurant_pictures_infos[@restaurant_id].first : @all_restaurants_infos[@restaurant_id][:picture_url]
    json.restaurant_id             @restaurant_id
    json.restaurant_food           @all_restaurants_infos[@restaurant_id][:food]
    if @all_restaurants_infos[@restaurant_id][:price_range] != nil
      json.restaurant_price_range  @all_restaurants_infos[@restaurant_id][:price_range]
    end
    if activity.trackable_type == "Recommendation"
      json.review                  @all_recommendations_infos[activity.trackable_id][:review]
    end
    json.date                      activity.created_at.strftime('%-d %B')


  else

    if activity.trackable_type == "Recommendation"
      @restaurant_id = @all_recommendations_infos[activity.trackable_id][:restaurant_id]
    elsif activity.trackable_type == "Wish"
      @restaurant_id = @all_wishes_infos[activity.trackable_id]
    end
    json.user_id                   activity.owner_id
    json.restaurant_id             @restaurant_id
    json.date                      activity.created_at
    json.user_type                 @all_users_infos[activity.owner_id][:type]
    json.notification_type         activity.trackable_type

  end

end