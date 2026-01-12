class Icons::PlusComponent < ViewComponent::Base
  def initialize(extra_classes: "")
    @extra_classes = extra_classes
  end

  def call
    classes = "w-5 h-5 #{@extra_classes}"
    # Heroicons Mini (Solid 20x20) Plus
    svg_content = <<~SVG
      <path d="M10.75 4.75a.75.75 0 0 0-1.5 0v4.5h-4.5a.75.75 0 0 0 0 1.5h4.5v4.5a.75.75 0 0 0 1.5 0v-4.5h4.5a.75.75 0 0 0 0-1.5h-4.5v-4.5Z" />
    SVG

    content_tag :svg, svg_content.html_safe,
      xmlns: "http://www.w3.org/2000/svg",
      viewBox: "0 0 20 20",
      fill: "currentColor",
      class: classes
  end
end
