module Icons
  class ClockComponent < ViewComponent::Base
    def initialize(classes: "w-6 h-6")
      @classes = classes
    end

    def call
      tag.svg(xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", stroke_width: "1.5", stroke: "currentColor", class: @classes, aria: { hidden: "true" }) do
        tag.path(stroke_linecap: "round", stroke_linejoin: "round", d: "M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z")
      end
    end
  end
end
