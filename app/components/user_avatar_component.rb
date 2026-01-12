class UserAvatarComponent < ViewComponent::Base
  def initialize(user:, size: :medium, extra_classes: "")
    @user = user
    @size = size
    @extra_classes = extra_classes
  end

  def render?
    @user.present?
  end

  private

  def size_classes
    case @size
    when :xs
      "w-6 h-6 text-[10px]"
    when :small
      "w-8 h-8 text-xs"
    when :medium
      "w-10 h-10 text-sm"
    when :large
      "w-14 h-14 text-lg"
    when :xl
      "w-20 h-20 text-xl"
    else
      "w-10 h-10 text-sm"
    end
  end

  def container_classes
    base = "rounded-full flex items-center justify-center font-bold shadow-sm"
    "#{base} #{size_classes} #{bg_color_class} #{@extra_classes}"
  end

  def image_classes
    "#{size_classes} rounded-full object-cover shadow-sm #{@extra_classes}"
  end

  def bg_color_class
    "bg-gray-200 text-gray-500 border-2 border-white"
  end

  def initial
    @user&.display_name&.first || "?"
  end
end
