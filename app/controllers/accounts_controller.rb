class AccountsController < ApplicationController
  before_action :authenticate_user!

  def show
    @required_profile_fields = {
      "Full name" => current_user.full_name,
      "Address" => current_user.address,
      "City" => current_user.city,
      "Postal code" => current_user.postal_code,
      "Province" => current_user.province
    }
    @missing_profile_fields = @required_profile_fields.select { |_label, value| value.blank? }.keys
  end
end
