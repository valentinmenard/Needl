class ApplicationController < ActionController::Base
  include PublicActivity::StoreController
  before_action :authenticate_user!, unless: :pages_or_subscribers_controller?
  before_action :count_notifs
  before_action :tracking

  # on laisse unless pages_controller au cas ou pour l'instant
  # include Pundit

  protect_from_forgery with: :exception
  before_filter :configure_permitted_parameters, if: :devise_controller?

  # after_action :verify_authorized, except:  :index, unless: :devise_or_pages_controller?
  # after_action :verify_policy_scoped, only: :index, unless: :devise_or_pages_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized


  protected

  def count_notifs
    if user_signed_in?
      activities = PublicActivity::Activity.where(owner_id: current_user.my_friends_ids, owner_type: 'User').order('created_at DESC').limit(20)
      @notification_count = activities.where(read: false).first == nil ? 0 : activities.where(read: false).count
    end
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:account_update) << :name
  end

  def after_sign_in_path_for(resource_or_scope)
    restaurants_path
  end

  def after_sign_out_path_for(resource_or_scope)
    restaurants_path
  end

  private

  def devise_or_pages_controller?
    devise_controller? || pages_controller?
  end

  def pages_or_subscribers_controller?
    controller_name == "pages" || controller_name == "subscribers"  # Brought by the `high_voltage` gem
  end

  def user_not_authorized
    flash[:error] = I18n.t('controllers.application.user_not_authorized', default: "You can't access this page.")
    redirect_to(root_path)
  end

  def tracking
    @tracker = Mixpanel::Tracker.new(ENV['MIXPANEL_TOKEN'])
  end

end
