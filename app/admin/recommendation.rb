ActiveAdmin.register Recommendation do

  permit_params :ambiences, :strengths, :review, :restaurant_id, :user_id, :occasions, :price_ranges, :friends_thanking, :contacts_thanking, :experts_thanking

  filter :restaurant, collection: Restaurant.all.order(:name)
  filter :user, collection: User.all.order(:name)

  form do |f|
    f.inputs "Recommendation" do
      f.input :restaurant, collection: Restaurant.all.order(:name)
      f.input :user, collection: User.all.order(:name)
      f.input :ambiences
      f.input :strengths
      f.input :occasions
      f.input :review
    end
    f.actions
  end

end
