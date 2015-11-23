module Api
  class RecommendationsController < ApplicationController
    acts_as_token_authentication_handler_for User
    skip_before_action :verify_authenticity_token
    skip_before_filter :authenticate_user!

    def index
      @user = User.find_by(authentication_token: params["user_token"])
      load_activities
      if params['recommendation']
        create
      elsif params['destroy']
        destroy
      else
        @tracker.track(@user.id, 'notif_page', { "user" => @user.name })
      end

    end

    def modify
      @user = User.find_by(authentication_token: params["user_token"])
      @restaurant = Restaurant.find(params["restaurant_id"])
      @recommendation = Recommendation.where(restaurant_id: @restaurant.id, user_id: @user.id).first
    end

    private

    def create

      is_a_wish = params[:recommendation][:wish]
      if is_a_wish == "true"
        create_a_wish
      else
        # si l'utilisateur a déà recommandé cet endroit alors on actualise sa reco
        if Recommendation.where(restaurant_id:params["restaurant_id"].first(4).to_i, user_id: @user.id).any?
          update

        # Si c'est une nouvelle recommandation on check que la personne a bien choisi un resto parmis la liste et on identifie ou crée le restaurant via la fonction
        elsif identify_or_create_restaurant != nil

          # On crée la recommandation à partir des infos récupérées
          @recommendation = @user.recommendations.new(recommendation_params)
          @recommendation.restaurant = @restaurant
          @recommendation.review = ( recommendation_params["review"] != "" && recommendation_params["review"] != nil ) ? recommendation_params["review"] : "Je recommande !"
          #  si les informations récupérées ont bien toutes été remplies on enregistre la reco, update le prix du resto et on le track
          if @recommendation.save


            @recommendation.restaurant.update_price_range(@recommendation.price_ranges.first)
            @tracker.track(@user.id, 'New Reco', { "restaurant" => @restaurant.name, "user" => @user.name })
            notif_reco("recommendation")

            # si c'était sur ma liste de wish ça l'enlève
            if Wish.where(restaurant_id:params["restaurant_id"].to_i, user_id: @user.id).any?
              Wish.where(restaurant_id:params["restaurant_id"].to_i, user_id: @user.id).first.destroy
              @tracker.track(@user.id, 'Wish to Reco', { "restaurant" => @restaurant.name, "user" => @user.name })
            end
            # si première recommandation ou wish, alors devient pote avec ceo, pour la première, à la sortie de l'onboarding, faire en sorte qu'on ne lui propose pas de wishlister
            if @user.recommendations.count == 1 && @user.wishes.count == 0
              Friendship.create(sender_id: 125, receiver_id: @user.id, accepted: true)
              # accept_all_friends
            end
            redirect_to api_restaurant_path(@recommendation.restaurant_id, :user_email => params["user_email"], :user_token => params["user_token"])

          # si certaines infos nécessaires n'ont pas été remplies
          else
            redirect_to new_api_recommendation_path(:user_email => params["user_email"], :user_token => params["user_token"], :notice =>"Les ambiances, points forts ou le prix n'ont pas été remplis")
          end

        # Si le restaurant n'a pas été pioché dans la liste, on le redirige sur la même page
        else
          redirect_to new_api_recommendation_path(:user_email => params["user_email"], :user_token => params["user_token"], :notice => "Nous n'avons pas retrouvé votre restaurant, choisissez parmi la liste qui vous est proposée")
        end
      end
    end

    def destroy
      reco = Recommendation.where(user_id: @user.id, restaurant_id: params['restaurant_id'].to_i).first
      if PublicActivity::Activity.where(trackable_type: "Recommendation", trackable_id: reco.id).length > 0
        activity = PublicActivity::Activity.where(trackable_type: "Recommendation", trackable_id: reco.id).first
        activity.destroy
      end
      reco.destroy
      redirect_to api_restaurants_path(:user_email => params["user_email"], :user_token => params["user_token"], :notice => "Le restaurant a bien été retiré de vos recommandations")
    end


    def identify_or_create_restaurant

      if  params[:restaurant_origin] == "db" || params[:restaurant_origin] == "foursquare"

        @restaurant_id      = params[:restaurant_id]
        @restaurant_name    = params[:restaurant_name]
        @restaurant_origin  = params[:restaurant_origin]

        if @restaurant_origin == "foursquare"
          @restaurant = create_restaurant_from_foursquare
        else
          @restaurant = Restaurant.find(@restaurant_id)
        end

      else
        nil
      end

    end

    def create_restaurant_from_foursquare
      client = Foursquare2::Client.new(
        api_version:    ENV['FOURSQUARE_API_VERSION'],
        client_id:      ENV['FOURSQUARE_CLIENT_ID'],
        client_secret:  ENV['FOURSQUARE_CLIENT_SECRET']
      )

      search = client.venue(@restaurant_id)
      restaurant = Restaurant.where(name: @restaurant_name).first_or_initialize(
        name:         search.name,
        address:      "#{search.location.address}",
        city:         "#{search.location.city}",
        postal_code:  "#{search.location.postalCode}",
        full_address: "#{search.location.address}, #{search.location.city} #{search.location.postalCode}",
        food:         Food.where(name: search.categories[0].shortName).first_or_create,
        latitude:     search.location.lat,
        longitude:    search.location.lng,
        picture_url:  search.photos.groups[0] ? "#{search.photos.groups[0].items[0].prefix}1000x1000#{search.photos.groups[0].items[0].suffix}" : "restaurant_default.jpg",
        phone_number: search.contact.phone ? search.contact.phone : nil
      )

      # pour rendre plus vite dans l'api
      restaurant.food_name = Food.find(restaurant.food_id).name

      if restaurant.save
        link_to_subways(restaurant)
        # pour créer le RestaurantType correspondant
        restaurant.attribute_category_from_food
        return restaurant
      else
        flash[:alert] = "Nous ne parvenons pas à trouver ce restaurant"
        return redirect_to new_api_recommendation_path(query: @query, :user_email => params["user_email"], :user_token => params["user_token"])
      end
    end

    def create_a_wish
      # si l'utilisateur a déjà mis sur sa liste de souhaits cet endroit (sachant que ça peut être fait depuis 2 endroits) alors on le lui dit et différemment suivant que provient de l'app ou d'un mail
      if params["restaurant_id"].length <= 9 && Wish.where(restaurant_id:params["restaurant_id"].to_i, user_id: @user.id).any?

        if params["origin"] == "mail"
          sign_out
          render(:json => {notice: "Ce restaurant était déjà sur ta wishlist ! Tu peux le retrouver en te connectant sur l'app !"}, :status => 409, :layout => false)
        else

          render(:json => {notice: "Restaurant déjà sur ta wishlist"}, :status => 409, :layout => false)

        end

      # Si c'est une nouvelle whish on check que la personne a bien choisi un resto parmis la liste et on identifie ou crée le restaurant via la fonction
      elsif identify_or_create_restaurant != nil

        # On vérifie qu'il n'a pas déjà recommandé l'endroit, sinon pas de raison de le mettre dans les restos à tester. La reaction dépend du fait qu"il vienne de l'app ou d'un mail
        if params["restaurant_id"].length <= 9 && Recommendation.where(restaurant_id:params["restaurant_id"].to_i, user_id: @user.id).length > 0

          if params["origin"] == "mail"
            sign_out
            render(:json => {notice: "Cette adresse fait déjà partie des restaurants que tu recommandes ! Tu peux le retrouver en te connectant sur l'app !"}, :status => 409, :layout => false)
          else

            render(:json => {notice: "Cette adresse fait déjà partie des restaurants que tu recommandes"}, :status => 409, :layout => false)
          end
        else

          # On crée la recommandation à partir des infos récupérées et on track
          @wish = Wish.create(user_id: @user.id, restaurant_id: @restaurant.id)
          # @wish.restaurant = @restaurant
          @tracker.track(@user.id, 'New Wish', { "restaurant" => @restaurant.name, "user" => @user.name })
          notif_reco("wish")

          # si première wish ou reco, devient pote avec Needl: à supprimer, ne devrait plus etre possible
          if @user.wishes.count == 1 && @user.recommendations.count == 0
            Friendship.create(sender_id: 125, receiver_id: @user.id, accepted: true)
          end

          #  Verifier si la wishlist vient de l'app ou d'un mail
          if params["origin"] == "mail"
          sign_out
          render(:json => {notice: "Le restaurant a bien été ajouté à ta wishlist ! Tu peux le retrouver en te connectant sur l'app !"}, :status => 409, :layout => false)

          else
            redirect_to api_restaurant_path(@wish.restaurant_id, :user_email => params["user_email"], :user_token => params["user_token"])
          end
        end

      # Si le restaurant n'a pas été pioché dans la liste, on le redirige sur la même page
      else
        redirect_to api_new_recommendation_path(:user_email => params["user_email"], :user_token => params["user_token"], :notice => "Nous n'avons pas retrouvé votre restaurant, choisissez parmi la liste qui vous est proposée")
      end
    end

    def link_to_subways(restaurant)
      client = GooglePlaces::Client.new(ENV['GOOGLE_API_KEY'])
      # stations erronnées reconnaissables à leur nom
      false_subway_stations_by_name = [
        "Elysees Metro Hub", "Métro invalides",
        "Metro Saint-Paul",
        "Metro Station Anvers",
        "Métro Saint Germain des Près",
        "Paris train station",
        "Station de Métro Les Halles",
        "Paris Est"]

        false_subway_stations_by_coordinates = [
          [48.870871, 2.332217],
          [48.876305, 2.333199],
          [48.831483, 2.355692],
          [48.869644, 2.336445],
          [48.853387, 2.343706],
          [48.867531, 2.313542],
          [48.882598, 2.309639],
          [48.865299, 2.374381],
          [48.861272, 2.374214]]


      search_less_than_500_meters = client.spots(restaurant.latitude, restaurant.longitude, :radius => 500, :types => 'subway_station')

      # on enleve toutes les stations erronees

      search_less_than_500_meters.delete_if { |result| false_subway_stations_by_name.include?(result.name)}
      search_less_than_500_meters.delete_if do|result|
        coordinates_result = [result.lat, result.lng]
        false_subway_stations_by_coordinates.include?(coordinates_result)
      end

      # recherche du plus près au cas où il n'y en ait pas dans les 500m

      search_by_closest = client.spots(restaurant.latitude, restaurant.longitude, :rankby => 'distance', :types => 'subway_station')[0..5]

      # on enlève toutes les stations erronées
      search_by_closest.delete_if { |result| false_subway_stations_by_name.include?(result.name)}
      search_by_closest.delete_if do|result|
        coordinates_result = [result.lat, result.lng]
        false_subway_stations_by_coordinates.include?(coordinates_result)
      end
      search_by_closest = search_by_closest.first
      # on récupère le tout

      search = search_less_than_500_meters.length > 0 ? search_less_than_500_meters : [search_by_closest]

      # on associe chaque station de metro au restaurant

      search.each do |result|
        if Subway.find_by(latitude: result.lat) == nil
          subway = create_new_subway(result)
        else
          subway = Subway.find_by(latitude: result.lat)
        end
        restaurant_subway = RestaurantSubway.create(
          restaurant_id: restaurant.id,
          subway_id:     subway.id
          )
      end
      # enregistrer les subways dans la base de données restos pour rendre plus rapidement l'api
      restaurant.subway_id = restaurant.closest_subway_id
      restaurant.subway_name = Subway.find(restaurant.subway_id).name
      array = []
      restaurant.subways.each do |subway|
        array << {subway.id => subway.name}
      end
      restaurant.subways_near = array

      restaurant.save

    end


    def create_new_subway(result)
      subway = Subway.create(
        name:      result.name,
        latitude:  result.lat,
        longitude: result.lng
        )
      result = Geocoder.search("#{result.lat}, #{result.lng}").first.data["address_components"]
      result.each do |component|
        if component["types"].include?("locality")
          city = component["long_name"]
          subway.city = city
          subway.save
        end
      end
      return subway
    end

    def recommendation_params
      params.require(:recommendation).permit(:review, :wish, { strengths: [] }, { ambiences: [] }, { price_ranges: [] })
    end

    def load_activities
      @api_activities = PublicActivity::Activity.where(owner_id: @user.my_visible_friends_ids, owner_type: 'User').order('created_at DESC')
    end

    def update
      recommendation = Recommendation.where(restaurant_id:params["restaurant_id"].to_i, user_id: @user.id).first
      recommendation.update_attributes(recommendation_params)
      redirect_to api_restaurant_path(recommendation.restaurant_id, :user_email => params["user_email"], :user_token => params["user_token"])
    end

    def accept_all_friends
      friends = @user.user_friends
      if friends.length > 0
        friends.each do |friend|
          @friend = friend
          friendship = Friendship.create(sender_id: @user.id, receiver_id: @friend.id, accepted: true)
          @tracker.track(@user.id, 'add_friend', { "user" => @user.name })
          notif_friendship
          @friend.send_new_friend_email(@user)
        end
      end

    end

    def notif_friendship

      client = Parse.create(application_id: ENV['PARSE_APPLICATION_ID'], api_key: ENV['PARSE_API_KEY'])
        # envoyer à @friend qu'il a été accepté
        data = { :alert => "#{@user.name} te fait découvrir ses restos!", :badge => 'Increment', :type => 'friend' }
        push = client.push(data)
        # push.type = "ios"
        query = client.query(Parse::Protocol::CLASS_INSTALLATION).eq('user_id', @friend.id)
        push.where = query.where
        push.save

    end

    def notif_reco(status)

      client = Parse.create(application_id: ENV['PARSE_APPLICATION_ID'], api_key: ENV['PARSE_API_KEY'])

      if status == "recommendation" && current_user.my_friends_seing_me_ids != []
       # envoyer à chaque friend que @user a fait une nouvelle reco du resto @restaurant
       data = { :alert => "#{@user.name} a recommande #{@restaurant.name}", :badge => 'Increment', :type => 'reco' }
       push = client.push(data)
       # push.type = "ios"
       query = client.query(Parse::Protocol::CLASS_INSTALLATION).value_in('user_id', @user.my_friends_seing_me_ids)
       push.where = query.where
       push.save

       # attention si remet en wish, a adapter au code ci-dessus

      # else
      #   # envoyer à chaque friend que @user a fait un nouveau wish du resto @restaurant
      #   data = { :alert => "#{@user.name} a ajoute #{@restaurant.name} sur sa wishlist", :badge => 'Increment', :type => 'reco'  }
      #   push = client.push(data)
      #   # push.type = "ios"
      #   query = client.query(Parse::Protocol::CLASS_INSTALLATION).eq('user_id', @user.my_friends_seing_me_ids)
      #   push.where = query.where
      #   push.save
      end

    end

    def read_all_notification
      load_activities
      @activities.each do |activity|
        activity.read = true
        activity.save
      end
    end
  end
end
