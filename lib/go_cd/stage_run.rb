module GoCD

  class StageRun

    attr_reader :completed_at, :materials, :dependencies, :instance, :pipeline_name, :pipeline_counter, :result

    def initialize(stage)
      @completed_at = stage.completed_at
      @result = stage.result
      @materials = stage.pipeline.materials
      @dependencies = stage.pipeline.dependencies
      @pipeline_name = stage.pipeline.name
      @pipeline_counter = stage.pipeline.counter
      @instance = [@pipeline_name, @pipeline_counter, stage.name, stage.counter].map(&:to_s).join("/")
    end

  end

end
