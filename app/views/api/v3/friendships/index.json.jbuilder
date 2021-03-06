json.requests_received      @requests_received_users do |request|
  json.friendship_id              @requests_received_id[request.id]
  json.fullname                   request.name
  json.picture                    request.picture
  json.id                         request.id
end

json.requests_sent          @requests_sent_users do |request|
  json.friendship_id              @requests_sent_id[request.id]
  json.fullname                   request.name
  json.picture                    request.picture
  json.id                         request.id
end

json.friends                @friends do |friend|
  json.friendship_id              @infos[friend.id][:friendship_id]
  json.id                         friend.id
  json.name                       friend.name.split(" ")[0]
  json.fullname                   friend.name
  json.picture                    friend.picture
  json.score                      friend.score
  json.invisible                  @infos[friend.id][:invisibility]
  if @category_1.include?(friend.id)
    json.correspondence_score     1
  elsif @category_2.include?(friend.id)
    json.correspondence_score     2
  elsif @category_3.include?(friend.id)
    json.correspondence_score     3
  end
  json.recommendations            @friends_recommendations[friend.id] ? @friends_recommendations[friend.id] : []
  json.wishes                     @friends_wishes[friend.id] ? @friends_wishes[friend.id] : []
  json.followings                 @all_followings[friend.id] ? @all_followings[friend.id] : []
  json.friends                    @infos[friend.id][:friends]
  json.public                     friend.public
  json.public_score               friend.public_score
  json.number_of_followers        @all_followers[friend.id] ? @all_followers[friend.id].length : 0
  json.description                friend.description
  json.tags                       friend.tags
  json.public_recommendations     @all_public_recos[friend.id] ? @all_public_recos[friend.id] : []
  json.url                        friend.url
end


