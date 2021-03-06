class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController

  def facebook
    if request.env['omniauth.params']['action'] == 'facebook_link'
      user = User.find_by(authentication_token: request.env['omniauth.params']['user_token'])
      link_account_to_facebook(request.env["omniauth.auth"], 'facebook_link', user)
    else
      @user = User.find_for_facebook_oauth(request.env["omniauth.auth"])
      if @user.token_expiry  && @user.token_expiry < Time.now
        @user.token = request.env["omniauth.auth"].credentials.token
        @user.token_expiry = Time.at(request.env["omniauth.auth"].credentials.expires_at)
        @user.save
      end

      # Pour tous ceux qui sont rentrés sur l'app avant qu'on mette e système pour récupérer la date de naissance
      # if @user.birthday == nil
      #   @user.birthday = Date.parse(request.env["omniauth.auth"].extra.raw_info.birthday)
      #   @user.save
      # end

      if @user.persisted?
        if request.env['omniauth.params']['origin'] == 'app'
          if request.env['omniauth.params']['token'] != nil
            @user.update_attribute(:android_temporary_token, request.env['omniauth.params']['token'])
          end
          redirect_to new_subscriber_path
        else
          sign_in @user
          if @user.sign_in_count == 2
            # Création de compte

            # On track l'arrivée sur Mixpanel

            # les personnes suivent automatiquement les influenceurs
            User.where(public: true).each do |influencer|
              Followership.create(follower_id: @user.id, following_id: influencer.id)
            end

            @tracker.people.set(@user.id, {
              "gender" => @user.gender,
              "name" => @user.name,
              "$email": @user.email
            })

            if request.env['omniauth.params']['influencer_id'] != nil
              @tracker.track(@user.id, 'signup', {"@user" => @user.name, "source" => "influencer", "influencer" => User.find(request.env['omniauth.params']['influencer_id'].to_i).name } )
            end

            accept_all_friends

            if @user.email.include?("needlapp.com") == false && Rails.env.development? != true

              begin
                @gibbon = Gibbon::Request.new(api_key: ENV['MAILCHIMP_API_KEY'])
                @list_id = ENV['MAILCHIMP_LIST_ID_NEEDL_USERS']
                @gibbon.lists(@list_id).members.create(
                  body: {
                    email_address: @user.email,
                    status: "subscribed",
                    merge_fields: {
                      FNAME: @user.name.partition(" ").first,
                      LNAME: @user.name.partition(" ").last,
                      TOKEN: @user.authentication_token,
                      GENDER: @user.gender ? @user.gender : ""
                    }
                  }
                )
              rescue Gibbon::MailChimpError
                # MailChimpError
              end

            end

            if request.env['omniauth.params'].length > 0 && request.env['omniauth.params']['from'] == 'wish'
              restaurant_id = request.env['omniauth.params']['restaurant_id'].to_i
              if Wish.where(user_id: @user.id, restaurant_id: restaurant_id).length > 0
                # already wishlisted
                redirect_to wish_failed_subscribers_path(message: 'already_wishlisted')
              elsif Recommendation.where(user_id: @user.id, restaurant_id: restaurant_id).length > 0
                # already recommended
                redirect_to wish_failed_subscribers_path(message: 'already_recommended')
              else
                Wish.create(user_id: @user.id, restaurant_id: restaurant_id, influencer_id: request.env['omniauth.params']['influencer_id'].to_i)
                if Rails.env.production? == true
                  @tracker.track(@user.id, 'New Wish', { "restaurant" => Restaurant.find(restaurant_id).name, "user" => @user.name, "source" => "influencer", "influencer" => User.find(request.env['omniauth.params']['influencer_id'].to_i).name })
                end
                redirect_to wish_success_subscribers_path(message: 'account_creation')
              end
            else
              redirect_to new_recommendation_path, notice: "Partage ta première reco avant de découvrir celles de tes amis"
            end
          else
            # Log in
            if request.env['omniauth.params']['influencer_id'] != nil
              @tracker.track(@user.id, 'signin', {"user" => @user.name, "source" => "influencer", "influencer" => User.find(request.env['omniauth.params']['influencer_id'].to_i).name } )
            end
            if request.env['omniauth.params'].length > 0 && request.env['omniauth.params']['from'] == 'wish'
              restaurant_id = request.env['omniauth.params']['restaurant_id'].to_i
              if Wish.where(user_id: @user.id, restaurant_id: restaurant_id).length > 0
                # already wishlisted
                redirect_to wish_failed_subscribers_path(message: 'already_wishlisted')
              elsif Recommendation.where(user_id: @user.id, restaurant_id: restaurant_id).length > 0
                # already recommended
                redirect_to wish_failed_subscribers_path(message: 'already_recommended')
              else
                Wish.create(user_id: @user.id, restaurant_id: restaurant_id, influencer_id: request.env['omniauth.params']['influencer_id'].to_i)
                if Rails.env.production? == true
                  @tracker.track(@user.id, 'New Wish', { "restaurant" => Restaurant.find(restaurant_id).name, "user" => @user.name, "source" => "influencer", "influencer" => User.find(request.env['omniauth.params']['influencer_id'].to_i).name })
                end
                redirect_to wish_success_subscribers_path
              end

            else
              redirect_to root_path
            end
          end
        end

      else
        session["devise.facebook_data"] = request.env["omniauth.auth"]
        redirect_to new_user_registration_url, notice: "Votre adresse mail renseignée sur Facebook est périmée, pour avoir accès à n'importe quelle application via Facebook connect vous devez désormais aller des les paramètres et la changer."
      end
    end
  end

  def facebook_access_token
    if params["link_to_facebook"] == "true"
      link_account_to_facebook(request.env["omniauth.auth"])
    else
      @user = User.find_for_facebook_oauth(request.env["omniauth.auth"])
      #  Pas hyper sur que ca serve a quelque chose puisque les nouvelles personnes n'ont pas d'expire_at
      if @user.token_expiry && @user.token_expiry < Time.now
        @user.token = request.env["omniauth.auth"].credentials.token
        if request.env["omniauth.auth"].credentials.expires_at
          @user.token_expiry = Time.at(request.env["omniauth.auth"].credentials.expires_at)
        else
          @user.token_expiry = nil
        end
        @user.save
      end

      # Pour tous ceux qui sont rentrés sur l'app avant qu'on mette e système pour récupérer la date de naissance
      # if @user.birthday == nil
      #   @user.birthday = Date.parse(request.env["omniauth.auth"].extra.raw_info.birthday)
      #   @user.save
      # end

      if @user.persisted?
        sign_in @user#, event: :authentication

        # Si c'est un signup

        if @user.sign_in_count == 2

          # On track l'arrivée sur Mixpanel

          # les personnes suivent automatiquement les influenceurs
          User.where(public: true).each do |influencer|
            Followership.create(follower_id: @user.id, following_id: influencer.id)
          end

          @tracker.people.set(@user.id, {
            "gender" => @user.gender,
            "name" => @user.name,
            "$email": @user.email
          })
          @tracker.track(@user.id, 'signup', {"user" => @user.name} )

          accept_all_friends

          # s'il a reçu un point d'expertise
          if params["friend_id"] != nil && params["restaurant_id"] != nil && Recommendation.where(user_id: params["friend_id"], restaurant_id: params["restaurant_id"]).length > 0
            if @user.my_friends_ids.include?(params["friend_id"]) == false
              Friendship.create(sender_id: params["friend_id"], receiver_id: @user.id, accepted: true)
            end
            reco = Recommendation.where(user_id: params["friend_id"], restaurant_id: params["restaurant_id"]).first
            reco.friends_thanking += [@user.id]
            reco.save
            @user.update_attribute(:score, 1)

            @tracker.track(@user.id, 'Signup Thanked', { "user" => @user.name, "friend" => reco.user.name, "restaurant" => reco.restaurant.name})
          end

          # On ajoute le nouveau membre sur la mailing liste de mailchimp
          if @user.email.include?("needlapp.com") == false && Rails.env.development? != true

            begin
              @gibbon = Gibbon::Request.new(api_key: ENV['MAILCHIMP_API_KEY'])
              @list_id = ENV['MAILCHIMP_LIST_ID_NEEDL_USERS']
              @gibbon.lists(@list_id).members.create(
                body: {
                  email_address: @user.email,
                  status: "subscribed",
                  merge_fields: {
                    FNAME: @user.name.partition(" ").first,
                    LNAME: @user.name.partition(" ").last,
                    TOKEN: @user.authentication_token,
                    GENDER: @user.gender ? @user.gender : ""
                  }
                }
              )
            rescue Gibbon::MailChimpError
              # MailChimpError
            end

          end
      #  Si c'est un login
        else
          @tracker.track(@user.id, 'signin', {"user" => @user.name} )
        end
        render json: {user: @user, nb_recos: Restaurant.joins(:recommendations).where(recommendations: { user_id: @user.id }).count, nb_wishes: Restaurant.joins(:wishes).where(wishes: {user_id: @user.id}).count}
      else
        if Rails.env.development? == true
          puts "user rejected"
        end
      end
    end
  end

  def link_account_to_facebook(auth, callback, user)
    if callback == 'facebook_link'
      @user = user
    else
      @user = User.find_by(authentication_token: params["user_token"])
    end
    @user.link_account_to_facebook(auth)
    @tracker.track(@user.id, 'Account Linked to Facebook', {"user" => @user.name} )
    accept_new_friends
    if callback == 'facebook_link'
      redirect_to new_subscriber_path(message: 'facebook_link')
    else
      render json: {message: "success"}
    end

    # renvoyer des infos particulières ? (les activités, restaurants et profils de chaque nouvel utilisateur j'imagine)
  end

  def accept_all_friends
    friends = @user.user_friends
    if friends.length > 0
      friends.each do |friend|
        Friendship.create(sender_id: @user.id, receiver_id: friend.id, accepted: true)
        TasteCorrespondence.create(member_one_id: @user.id, member_two_id: friend.id, number_of_shared_restaurants: 0, category: 1)
        @tracker.track(@user.id, 'add_friend', { "user" => @user.name })
      end
    end
  end

  def accept_new_friends
    friends = @user.user_friends
    if friends.length > 0
      friends.each do |friend|
        if Friendship.where(sender_id: [@user.id, friend.id], receiver_id: [@user.id, friend.id]).length == 0
          Friendship.create(sender_id: @user.id, receiver_id: friend.id, accepted: true)
          TasteCorrespondence.create(member_one_id: @user.id, member_two_id: friend.id, number_of_shared_restaurants: 0, category: 1)
          @tracker.track(@user.id, 'add_friend', { "user" => @user.name })
        end
      end
    end
  end

end