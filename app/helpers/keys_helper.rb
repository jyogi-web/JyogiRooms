module KeysHelper
  def key_transferable?(key)
    effective_admin_or_manager? || key.user_id == current_user&.id
  end

  def key_unassignable?(key)
    effective_admin_or_manager?
  end
end
