module GoCD

  class GreenBuild

    attr_reader :completed_at, :materials, :dependencies, :instance

    def initialize(stage)
      @completed_at = stage.completed_at
      @materials = stage.pipeline.materials
      @dependencies = stage.pipeline.dependencies
      @instance = [stage.pipeline.name, stage.pipeline.counter, stage.name, stage.counter].map(&:to_s).join("/")
    end

  end

end
