class Ui::ConfirmModalComponent < ViewComponent::Base
  def initialize(id: nil, title: "確認", trigger_icon: nil, cancel_text: "キャンセル")
    @id = id || "modal_#{SecureRandom.hex(4)}"
    @title = title
    @trigger_icon = trigger_icon
    @cancel_text = cancel_text
  end
end
