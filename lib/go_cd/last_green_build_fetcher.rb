require 'bundler'
Bundler.setup
require 'go_api_client'
require 'pstore'
require 'benchmark'
require_relative 'green_build'

module GoCD
  class LastGreenBuildFetcher

    def initialize(options)
      @options = options
      @pipeline = @options[:pipeline_name]
      @stage = @options.delete(:stage_name)
      @cache = PStore.new(File.expand_path('./.last_green_build_fetcher_cache'))
      @options.merge!(:latest_atom_entry_id => recall(:latest_atom_entry_id))
      if @options[:latest_atom_entry_id].nil? && ENV['QUIET'].nil?
        puts "Retrieving the feed for #{@options[:pipeline_name]}/#{@stage} for the first time.  This could take awhile."
      end
    end

    def fetch
      feed = nil
      ms = Benchmark.realtime do
        feed = GoApiClient.runs(@options)
      end
      puts "fetched pipeline runs in #{ms/1000}sec" unless ENV['QUIET']

      pipelines = feed[:pipelines]
      remember(:latest_atom_entry_id, feed[:latest_atom_entry_id])
      puts "Checking for last green run of #{@stage}. Latest event: #{feed[:latest_atom_entry_id]}" unless ENV['QUIET']

      pipelines.reverse.each do |pipeline|
        stage = pipeline.stages.find { |stage| stage.name == @stage }
        if stage && stage.result == 'Passed'
          remember(:last_green_build, GreenBuild.new(stage.completed_at))
        end
      end

      recall :last_green_build
    end

    private

    def remember(key, value)
      @cache.transaction do
        if @cache[@pipeline]
          @cache[@pipeline].merge!(key => value)
        else
          @cache[@pipeline] = { key => value }
        end
      end
    end

    def recall(key)
      @cache.transaction(true) do
        @cache[@pipeline] && @cache[@pipeline][key]
      end
    end
  end
end
