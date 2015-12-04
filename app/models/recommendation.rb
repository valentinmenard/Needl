class Recommendation < ActiveRecord::Base
  include PublicActivity::Model
  belongs_to :user
  belongs_to :restaurant
  validates :strengths, presence: true
  validates :ambiences, presence: true
  validates :price_ranges, presence: true

  # A mettre quand on fait la migration sur l'AppStore!!!
  # validates :occasions, presence: true
  attr_accessor :wish
  has_many :activities, as: :trackable, class_name: 'PublicActivity::Activity', dependent: :destroy
  tracked owner: Proc.new { |controller, _model| controller.current_user }, only: [:create]
end
