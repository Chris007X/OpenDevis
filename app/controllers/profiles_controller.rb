class ProfilesController < ApplicationController
  def show
    @user = current_user
    authorize @user, policy_class: ProfilePolicy
  end

  def edit
    @user = current_user
    authorize @user, policy_class: ProfilePolicy
  end

  def update
    @user = current_user
    authorize @user, policy_class: ProfilePolicy

    if @user.update(profile_params)
      redirect_to profile_path, notice: "Profil mis à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:full_name, :phone, :location)
  end
end
