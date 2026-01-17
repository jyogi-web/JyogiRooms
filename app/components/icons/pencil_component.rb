module Icons
  class PencilComponent < ViewComponent::Base
    def initialize(classes: "w-6 h-6")
      @classes = classes
    end

    def call
      tag.svg(xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", stroke_width: "1.5", stroke: "currentColor", class: @classes, aria: { hidden: "true" }) do
        tag.path(stroke_linecap: "round", stroke_linejoin: "round", d: "M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.69 1.04l-5.183 1.34a.375.375 0 01-.47-.47l1.34-5.183a4.5 4.5 0 011.04-1.69L16.862 4.487zM16.862 4.487L19.5 7.125")
      end
    end
  end
end
