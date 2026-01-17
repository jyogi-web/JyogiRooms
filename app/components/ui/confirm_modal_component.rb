class Ui::ConfirmModalComponent < ViewComponent::Base
  def initialize(id: nil, title: "確認", trigger_icon: nil, confirm_text: "削除する", cancel_text: "キャンセル")
    @id = id || "modal_#{SecureRandom.hex(4)}"
    @title = title
    @trigger_icon = trigger_icon
    @confirm_text = confirm_text
    @cancel_text = cancel_text
  end
end
