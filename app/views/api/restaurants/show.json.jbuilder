json.id                         @restaurant.id
json.name                       @restaurant.name
json.food                      [@restaurant.food_id, @restaurant.food_name]
json.price_range                @restaurant.price_range
json.address                    @restaurant.address
json.pictures                   @pictures
json.latitude                   @restaurant.latitude
json.longitude                  @restaurant.longitude
json.subways                    @restaurant.subways_near
json.closest_subway             @restaurant.subway_id
json.phone_number               @restaurant.phone_number
if @user.app_version == nil
  json.ambiences                  @restaurant.old_ambiences_from_my_friends_and_experts_api(@user)
elsif @user.app_version == '2.0.0'
  json.ambiences                  @restaurant.ambiences_from_my_friends_and_experts_api_minus_one(@user)
else
  json.ambiences                  @restaurant.ambiences_from_my_friends_and_experts_api(@user)
end
if @user.app_version == '2.0.0'
  json.strengths                  @restaurant.strengths_from_my_friends_and_experts_api_minus_one(@user)
else
  json.strengths                  @restaurant.strengths_from_my_friends_and_experts_api(@user)
end
json.occasions                  @restaurant.occasions_from_my_friends_and_experts_api(@user)
json.reviews                    @restaurant.reviews_from_my_friends_and_experts(@user)
json.starter1                   @restaurant.starter1
json.description_starter1       @restaurant.description_starter1
json.price_starter1             @restaurant.price_starter1
json.starter2                   @restaurant.starter2
json.description_starter2       @restaurant.description_starter2
json.price_starter2             @restaurant.price_starter2
json.main_course1               @restaurant.main_course1
json.description_main_course1   @restaurant.description_main_course1
json.price_main_course1         @restaurant.price_main_course1
json.main_course2               @restaurant.main_course2
json.description_main_course2   @restaurant.description_main_course2
json.price_main_course2         @restaurant.price_main_course2
json.main_course3               @restaurant.main_course3
json.description_main_course3   @restaurant.description_main_course3
json.price_main_course3         @restaurant.price_main_course3
json.dessert1                   @restaurant.dessert1
json.description_dessert1       @restaurant.description_dessert1
json.price_dessert1             @restaurant.price_dessert1
json.dessert2                   @restaurant.dessert2
json.description_dessert2       @restaurant.description_dessert2
json.price_dessert2             @restaurant.price_dessert2
json.friends_wishing            @friends_wishing
json.my_friends_recommending    @my_friends_and_experts_recommending
json.my_friends_wishing         @my_friends_wishing


