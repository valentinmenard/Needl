class SubscribersController < ApplicationController
  skip_before_filter :verify_authenticity_token

  def create
    @gibbon = Gibbon::Request.new(api_key: ENV['MAILCHIMP_API_KEY'])
    @list_id = ENV['MAILCHIMP_LIST_ID_WAITING_ANDROID']

    @array = []
    @gibbon.lists(@list_id).members.retrieve["members"].each do |user|
      @array << user["email_address"]
    end

    if @array.include?(params["email"]) == false
      @gibbon.lists(@list_id).members.create(
        body: {
          email_address: params["email"],
          status: "subscribed"
        }
      )

    end
    redirect_to root_path(:subscribed => true)
  end

  def login
    delta_latitude = 0.0004
    delta_longitude = 0.0008

    if Rails.env.production? == true
      @tracker.track('Wishlist Page From Influencer', { "influencer" => User.find(params['influencer_id'].to_i).name })
    end

    url = request.referer

    if url != '' && url != nil
      domain = URI.parse(url).host.sub(/^www\./, '')
    else
      domain = ''
    end

    case domain
      when "716lavie.com"
        if Rails.env.development? == true
          puts 'from 716lavie.com'
        end

        page = Nokogiri.HTML(open(url))

        restaurant_name = page.css('div.foodnom').text.strip
        restaurant_name_in_array =restaurant_name.split(" ")
        restaurant_address = page.css('div.foodadress').text.strip
        restaurant_ids = []


      when "mademoisellebonplan.fr"
        if Rails.env.development? == true
          puts 'from mademoisellebonplan.fr'
        end

        page = Nokogiri.HTML(open(url))

        restaurant_name = page.css('div.entry-content h6')[0].text.strip
        restaurant_name_in_array = restaurant_name.split(" ")
        restaurant_address = page.css('div.entry-content h6')[1].text.strip
        restaurant_ids = []

      when "glutencorner.com"
        if Rails.env.development? == true
          puts 'from glutencorner.com'
        end

        page = Nokogiri.HTML(open(url))

        special_character_index = []

        restaurant_name = page.css('div.content h1.recette-titre').text.strip
        special_character_index << restaurant_name.index('(') 
        special_character_index << restaurant_name.index('-') 
        special_character_index << restaurant_name.index('–') 
        special_character_index << restaurant_name.index(':')
        special_character_index_minimum = special_character_index.compact.min

        if special_character_index_minimum != nil
          restaurant_name = restaurant_name[0, special_character_index_minimum]
        end

        restaurant_name_in_array = restaurant_name.split(" ")
        restaurant_address = page.css('p.recette-niveau')[2].text.strip
        restaurant_ids = []

      else
        if Rails.env.development? == true
          puts 'unknown to us'
        end
        restaurant_address = ''
        error_message = 'unknown_referer'

    end

    if Geocoder.search(restaurant_address).first != nil
      latitude = Geocoder.search(restaurant_address).first.data["geometry"]["location"]["lat"]
      longitude = Geocoder.search(restaurant_address).first.data["geometry"]["location"]["lng"]

      restaurants = Restaurant.where(["latitude < ? and latitude > ? and longitude < ? and longitude > ?", latitude + delta_latitude, latitude - delta_latitude, longitude + delta_longitude, longitude - delta_longitude])

      if restaurants != nil && restaurants.length > 0
        restaurants.each do |restaurant|
          restaurant_name_in_array.each do |word|
            if is_comparable_in_title(word) && (restaurant.name.include? word)
              restaurant_ids << restaurant.id
            else
              # no words in common in the title
              search_in_foursquare(restaurant_name, latitude, longitude, url)
            end
          end
        end
      else
        # no restaurants in specified zone in db, we search in Foursquare
        search_in_foursquare(restaurant_name, latitude, longitude, url)
      end

      if restaurant_ids.uniq.length == 1
        @origin = 'db'
        @restaurant = Restaurant.find(restaurant_ids).first
      else 
        if @restaurant == nil
          # multiple restaurants matching the location and name
          if Rails.env.production? == true
            @tracker.track('Multiple restaurants found', {'url' => url})
            error_message = 'multiple_restaurants'
          end
        end
      end

    else
      # no restaurants in specified zone from referer crawling and geocoder
      error_message = 'error_with_geocoder'
    end

    if @restaurant != nil && params['influencer_id'] != nil && params['influencer_id'].to_i != 0 && User.where(id: params['influencer_id'].to_i).length == 1
      if current_user != nil 
        # is already looged in, add wish immediately
        influencer = User.find(params['influencer_id'].to_i)

        if Wish.where(user_id: current_user.id, restaurant_id: @restaurant.id).length > 0
          # already wishlisted
          redirect_to wish_failed_subscribers_path(message: 'already_wishlisted')
        elsif Recommendation.where(user_id: current_user.id, restaurant_id: @restaurant.id).length > 0
          # already recommended
          redirect_to wish_failed_subscribers_path(message: 'already_recommended')
        else
          if @origin == 'db' || @origin = 'foursquare'
            Wish.create(user_id: current_user.id, restaurant_id: @restaurant.id, influencer_id: influencer.id)
          end
          if Rails.env.production? == true
            @tracker.track(current_user.id, 'New Wish', { "restaurant" => @restaurant.name, "user" => current_user.name, "source" => "influencer", "influencer" => influencer.name })
          end
          redirect_to wish_success_subscribers_path
        end
      else # show login page to add wish
        @user = User.new

        if (@restaurant != nil)
          @influencer_id = User.find(params['influencer_id'].to_i).id
          @picture = @restaurant.restaurant_pictures.first ? @restaurant.restaurant_pictures.first.picture : @restaurant.picture_url
        else
          redirect_to wish_failed_subscribers_path(message: 'inexistant_restaurant')
        end
      end

    else
      case error_message
        when "multiple_restaurants"
          redirect_to wish_failed_subscribers_path(message: 'multiple_restaurants')
        else
          redirect_to root_path

      end
    end
  end

  def wish_success
    if current_user == nil
      redirect_to root_path
    end

    case params['message']
      when 'account_creation'
        @message_welcome = "<h1>Bienvenue sur Needl !</h1><h2>Needl c'est l'application pour trouver où diner en moins de 5 minutes !</h2>"
        @message = "<h3>Ton restaurant a bien été ajouté à ta wishlist ! Tu peux le retrouver sur l'application, disponible sur l'AppStore.</h3>"

      else 
        @message_welcome = nil
        @message = "<h2>Ton restaurant a bien été ajouté à ta wishlist ! Tu peux le retrouver sur l'application, disponible sur l'AppStore.</h2>"

    end
  end

  def wish_failed
    if current_user == nil
      redirect_to root_path
    end

    case params['message']
      when 'already_wishlisted'
        @message = 'Tu as déja ce restaurant sur ta wishlist'
    
      when 'already_recommended'
        @message = 'Tu as déja recommandé ce restaurant'
      
      when 'inexistant_restaurant'
        @message = 'Le restaurant que tu essaies de mettre sur ta wishlist n\'existe pas :\'('

      when 'multiple_restaurants'
        @message = 'Une erreur s\'est produite lors de l\'ajout du restaurant à ta wishlist, ré-essaie un peu plus tard'

      else 
        @message = 'Une erreur s\'est produite lors de l\'ajout du restaurant à ta wishlist, ré-essaie un peu plus tard'

    end
  end

  private

  def is_comparable_in_title(word)
    excluded_words = ['les', 'des', 'bar', 'restaurant']
    return word.length > 2 && !(excluded_words.include? word.downcase)
  end

  def search_in_foursquare(name, latitude, longitude, url)
    client = Foursquare2::Client.new(
        api_version:    ENV['FOURSQUARE_API_VERSION'],
        client_id:      ENV['FOURSQUARE_CLIENT_ID'],
        client_secret:  ENV['FOURSQUARE_CLIENT_SECRET'])

    # On cherche les restaurants à partir de leurs coordonnés et on prend ceux à moins de 70 mètres (il y a des décalages avec ce que geocoder fait, car apparemment il change la géoloc une fois le restaurant crée, donc on met un peu de marge) avec en query leur nom
    search = client.search_venues(
      categoryId: "#{ENV['FOURSQUARE_FOOD_CATEGORY']},#{ENV['FOURSQUARE_BAR_CATEGORY']}",
      intent:     'browse',
      ll:         "#{latitude},#{longitude}",
      radius:     '70',
      query:      name
    )

    # On récupère tous les restaurants récupérés
    array = []
    search.first[1].each do |restaurant_foursquare|
      array << restaurant_foursquare
    end

    # Si un seul restaurant de récupéré, on l'ajoute en bdd
    if array.length > 0
      first_restaurant = array.first
      @restaurant = Restaurant.where(name: first_restaurant.name).first_or_create(
        name:               first_restaurant.name,
        address:            "#{first_restaurant.location.address}",
        city:               "#{first_restaurant.location.city}",
        postal_code:        "#{first_restaurant.location.postalCode}",
        full_address:       "#{first_restaurant.location.address}, #{first_restaurant.location.city} #{first_restaurant.location.postalCode}",
        food:               Food.where(name: first_restaurant.categories[0].shortName).first_or_create,
        latitude:           first_restaurant.location.lat,
        longitude:          first_restaurant.location.lng,
        price_range:        first_restaurant.attributes ? (first_restaurant.attributes.groups[0] ? first_restaurant.attributes.groups[0].items[0].priceTier : nil) : nil,
        picture_url:        first_restaurant.photos ? (first_restaurant.photos.groups[0] ? "#{first_restaurant.photos.groups[0].items[0].prefix}1000x1000#{first_restaurant.photos.groups[0].items[0].suffix}" : "http://needl.s3.amazonaws.com/production/restaurant_pictures/pictures/000/restaurant%20default.jpg") : "http://needl.s3.amazonaws.com/production/restaurant_pictures/pictures/000/restaurant%20default.jpg",
        phone_number:       first_restaurant.contact.phone ? first_restaurant.contact.phone : "",
        foursquare_id:      first_restaurant.id,
        foursquare_rating:  first_restaurant.rating
      )
      @origin = 'foursquare'
    else
      # plusieurs restaurants correspondent à la recherche
      if Rails.env.production? == true
        @tracker.track('Multiple restaurants found', { 'url' => url })
        error_message = 'multiple_restaurants'
      end
    end
  end

end
