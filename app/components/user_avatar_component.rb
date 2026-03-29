class UserAvatarComponent < ViewComponent::Base
  def initialize(user:, size: :medium, extra_classes: "", borderless: false, flat: false)
    @user = user
    @size = size
    @extra_classes = extra_classes
    @borderless = borderless
    @flat = flat
  end

  private

  def size_classes
    case @size
    when :xxs
      "w-3 h-3 text-[7px]"
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
    base = "rounded-full flex items-center justify-center font-bold"
    "#{base} #{size_classes} #{shadow_class} #{bg_color_class} #{@extra_classes}"
  end

  def image_classes
    "#{size_classes} rounded-full object-cover #{shadow_class} #{@extra_classes}"
  end

  def bg_color_class
    border_class = @borderless ? "" : "border-2 border-white"
    "bg-gray-200 text-gray-500 #{border_class}"
  end

  def shadow_class
    @flat ? "" : "shadow-sm"
  end

  def initial
    @user&.display_name&.first || "?"
  end
end
