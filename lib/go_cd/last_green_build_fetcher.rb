require 'bundler'
Bundler.setup
require 'go_api_client'
require 'pstore'
require 'benchmark'
require_relative 'stage_run'

module GoCD
  class LastGreenBuildFetcher

    PAGE_FETCH_LIMIT = 1

    def initialize(options)
      @options = options
      @pipeline = @options[:pipeline_name]
      @stage = @options.delete(:stage_name)
      cache_filename = @options[:cache_file] || default_cache_filename
      if File.exists?(cache_filename)
        log "[GoCD::LastGreenBuildFetcher] Reusing cache file: #{cache_filename}"
      else
        log "[GoCD::LastGreenBuildFetcher] Creating new cache file: #{cache_filename}"
      end
      @cache = PStore.new(cache_filename)
      @options.merge!(:latest_atom_entry_id => recall(:latest_atom_entry_id), :page_fetch_limit => PAGE_FETCH_LIMIT)
      if @options[:latest_atom_entry_id].nil? && ENV['QUIET'].nil?
        puts "Retrieving the the latest #{PAGE_FETCH_LIMIT} page(s) of the Go event feed for #{@options[:pipeline_name]}/#{@stage}."
      end
    end

    def fetch(filters={})
      feed = nil
      ms = Benchmark.realtime do
        feed = GoApiClient.runs(@options)
      end
      puts "fetched pipeline runs in #{ms/1000}sec" unless ENV['QUIET']

      pipelines = feed[:pipelines]
      puts "Checking for last green run of #{@stage}. Latest event: #{feed[:latest_atom_entry_id]}" unless ENV['QUIET']

      find_green_stage(pipelines: pipelines, filters: filters).tap do |stage|
        remember(:last_green_build, StageRun.new(stage)) if stage
      end

      remember(:latest_atom_entry_id, feed[:latest_atom_entry_id])
      recall :last_green_build
    end

    private

    def log(msg)
      puts msg unless ENV['QUIET']
    end

    def default_cache_filename
      dir = File.join(ENV['HOME'], ".last-green-go-pipeline-cache")
      FileUtils.mkdir_p(dir)
      File.join(dir, "#{@options[:host]}.pstore")
    end

    def find_green_stage(params)
      pipelines = params.delete(:pipelines)
      filter = params.delete(:filters)
      pipelines.reverse.each do |pipeline|
        stage = pipeline.stages.find { |stage| stage.name == @stage }
        if stage && stage.result == 'Passed'
          stage.pipeline = pipeline
          return stage if matches_filter(stage, filter)
        end
      end
      return nil
    end

    def matches_filter(stage, filters)
      return true unless filters && (filters[:dependencies] || filters[:materials])
      meets_dependencies_filter = (filters[:dependencies] || []).all? do |upstream_name, upstream_instance|
        stage.pipeline.dependencies.any? do |dependency|
          dependency.pipeline_name == upstream_name && dependency.identifier == upstream_instance
        end
      end
      meets_materials_filter = (filters[:materials] || []).all? do |filtered_material_name, git_revision|
        stage.pipeline.materials.any? do |git_material|
          repo_name = git_material.repository_url.split('/').last
          material_name = "#{repo_name}-git"
          filtered_material_name == material_name && git_revision == git_material.commits.first.revision
        end
      end
      meets_dependencies_filter && meets_materials_filter
    end

    def remember(key, value)
      @cache.transaction do
        if @cache[@pipeline]
          @cache[@pipeline].merge!(key => value)
        else
          @cache[@pipeline] = { key => value }
        end
      end
      value
    end

    def recall(key)
      @cache.transaction(true) do
        @cache[@pipeline] && @cache[@pipeline][key]
      end
    end
  end
end
