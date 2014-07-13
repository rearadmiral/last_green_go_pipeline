module GoCD

  class GreenBuild

    attr_reader :completed_at, :materials, :dependencies

    def initialize(stage)
      @completed_at = stage.completed_at
      @materials = stage.pipeline.materials
      @dependencies = stage.pipeline.dependencies
    end

  end

end
