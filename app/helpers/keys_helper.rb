module KeysHelper
  def key_transferable?(key)
    effective_admin? || key.user_id == current_user&.id
  end

  def key_unassignable?(key)
    effective_admin?
  end
end
