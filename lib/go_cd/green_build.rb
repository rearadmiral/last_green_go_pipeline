module GoCD

  class GreenBuild

    attr_reader :completed_at

    def initialize(completed_at)
      @completed_at = completed_at
    end


  end

end
