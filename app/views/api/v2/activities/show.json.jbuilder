json.user_id                   @activity.user_id
json.restaurant_id             @activity.restaurant_id
json.date                      @activity.created_at
json.user_type                 "me"
json.notification_type         @type
if @type == "recommendation"
  json.strengths               @activity.strengths
  json.ambiences               @activity.ambiences
  json.occasions               @activity.occasions
end
json.review                    @type == "Recommendation" ? @activity.review : "Sur ma wishlist"