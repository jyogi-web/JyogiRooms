module Icons
  class ArrowLeftComponent < ViewComponent::Base
    def initialize(classes: "w-6 h-6")
      @classes = classes
    end

    def call
      tag.svg(xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", stroke_width: "2", stroke: "currentColor", class: @classes, aria: { hidden: "true" }) do
        tag.path(stroke_linecap: "round", stroke_linejoin: "round", d: "M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18")
      end
    end
  end
end
