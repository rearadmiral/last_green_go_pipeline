require_relative '../lib/go_cd/last_green_build_fetcher'
require 'ostruct'

class MockGoApiClient

  def self.reset!
    @@last_params = @@canned_return_value = nil
  end

  def self.last_params
    @@last_params
  end

  def self.canned_return_value=(value)
    @@canned_return_value = value
  end

  def self.runs(options)
    @@last_params = options
    @@canned_return_value
  end

end

describe GoCD::LastGreenBuildFetcher do

  let(:cache_file) do
    File.expand_path('./.last_green_build_fetcher_cache')
  end

  before(:each) do
    FileUtils.rm_f cache_file
  end

  describe "with mock go api" do

    before(:each) do
      GoApiClient.instance_eval do
        class << self
          alias_method :original_runs_method, :runs
          def runs(options)
            MockGoApiClient.runs(options)
          end
        end
      end
    end

    describe "after first fetch" do

      before(:each) do

        @fetcher = GoCD::LastGreenBuildFetcher.new(stage_name: 'acceptance')

        MockGoApiClient.canned_return_value = {
          pipelines: [green_pipeline],
        }

        last_green_build = @fetcher.fetch
        @last_known_time = last_green_build.completed_at
        expect(@last_known_time).not_to be_nil

        MockGoApiClient.canned_return_value = {
          pipelines: []
        }

      end

      it "returns last known time" do
        expect(@fetcher.fetch.completed_at).to eq(@last_known_time)
      end

    end

    describe "with no pipeline history" do

      before(:each) do
        MockGoApiClient.canned_return_value = {
          pipelines: [],
        }
      end

      it "returns nil" do
        fetcher = GoCD::LastGreenBuildFetcher.new(stage_name: 'acceptance')
        expect(fetcher.fetch).to be nil
      end

    end

    describe "with no green builds" do

      before(:each) do
        MockGoApiClient.canned_return_value = {
          pipelines: [red_pipeline]
        }
      end

      it "returns nils" do
        fetcher = GoCD::LastGreenBuildFetcher.new(stage_name: 'acceptance')
        expect(fetcher.fetch).to be nil
      end

    end

    describe "the cache file" do

      let(:cache) do
        PStore.new(cache_file)
      end

      it "will be used to populate the fetcher params" do
        cache.transaction { cache['XYZ'] = { latest_atom_entry_id: 'http://go01.thoughtworks.com/feed/pipeline/XYZ/123.xml' }; cache.commit; }
        MockGoApiClient.canned_return_value = {
          pipelines: [red_pipeline],
          latest_atom_entry_id: 'http://go01.thoughtworks.com/feed/pipeline/XYZ/124.xml'
        }
        GoCD::LastGreenBuildFetcher.new(pipeline_name: 'XYZ', stage_name: 'acceptance').fetch
        expect(MockGoApiClient.last_params).to include(latest_atom_entry_id: 'http://go01.thoughtworks.com/feed/pipeline/XYZ/123.xml')
      end

      it "contains the latest atom id" do
        MockGoApiClient.canned_return_value = {
          pipelines: [red_pipeline],
          latest_atom_entry_id: 'osito'
        }
        GoCD::LastGreenBuildFetcher.new(pipeline_name: 'cached', stage_name: 'acceptance').fetch
        expect(cache.transaction(true) { cache['cached'][:latest_atom_entry_id] }).to eq 'osito'
      end

    end

    # it "finds most recent passing stage filtered by materials" do
    #   MockGoApiClient.canned_return_value = {
    #                                       pipelines: [red_pipeline, green_pipeline, older_green_pipeline].reverse
    #                                     }
    #   fetcher = GoCD::LastGreenBuildFetcher.new(stage_name: 'acceptance')
    #   last_green_build = fetcher.fetch(materials: [{'upstream' => 'upstream/2/ready_for_prod/3'}])
    #   expect(last_green_build.completed_at).to eq older_green_pipeline.stages.last.completed_at
    # end

    it "finds most recent passing stage" do
      MockGoApiClient.canned_return_value = {
                                          pipelines: [red_pipeline, green_pipeline, older_green_pipeline].reverse
                                        }
      fetcher = GoCD::LastGreenBuildFetcher.new(stage_name: 'acceptance')
      last_green_build = fetcher.fetch
      expect(last_green_build.completed_at).to eq Time.parse('2013-02-11 14:19:00')
    end

    it "knows the instance of the pipeline" do
      MockGoApiClient.canned_return_value = { pipelines: [green_pipeline] }
      fetcher = GoCD::LastGreenBuildFetcher.new(stage_name: 'acceptance')
      last_green_build = fetcher.fetch
      expect(last_green_build.instance).to eq 'osito/3/acceptance/1'
    end

    it "knows the pipeline name" do
      MockGoApiClient.canned_return_value = { pipelines: [green_pipeline] }
      fetcher = GoCD::LastGreenBuildFetcher.new(stage_name: 'acceptance')
      last_green_build = fetcher.fetch
      expect(last_green_build.pipeline_name).to eq 'osito'
    end

    it "knows the pipeline counter" do
      MockGoApiClient.canned_return_value = { pipelines: [green_pipeline] }
      fetcher = GoCD::LastGreenBuildFetcher.new(stage_name: 'acceptance')
      last_green_build = fetcher.fetch
      expect(last_green_build.pipeline_counter).to eq 3
    end

    it "knows the materials of the last green build" do
      MockGoApiClient.canned_return_value = {
                                          pipelines: [red_pipeline, green_pipeline].reverse
                                        }
      fetcher = GoCD::LastGreenBuildFetcher.new(stage_name: 'acceptance')
      stage_run = fetcher.fetch
      expect(stage_run.materials.size).to eq 1
      expect(stage_run.dependencies.size).to eq 1
    end

    after(:each) do
      MockGoApiClient.reset!
      GoApiClient.instance_eval do
        class << self
          alias_method :runs, :original_runs_method
        end
      end
    end

  end

  let(:red_pipeline) do
    OpenStruct.new.tap do |pipeline|
      pipeline.stages = [OpenStruct.new(
                            name: 'unit',
                                        result: 'Passed',
                                        completed_at: Time.parse('2013-02-12 11:40:00'),
                                        pipeline: pipeline),
                         OpenStruct.new(
                            name: 'acceptance',
                            result: 'Failed',
                                        completed_at: Time.parse('2013-02-12 11:45:00'),
                                        pipeline: pipeline)
                          ]
    end
  end

  let (:green_pipeline) do
    OpenStruct.new(dependencies: dependencies, materials: materials).tap do |pipeline|
      pipeline.name = 'osito'
      pipeline.counter = 3
      pipeline.stages = [OpenStruct.new(
                            name: 'unit',
                            result: 'Passed',
                                        completed_at: Time.parse('2013-02-11 14:10:00'),
                                        pipeline: pipeline),
                         OpenStruct.new(
                             name: 'acceptance',
                                        result: 'Passed',

                             completed_at: Time.parse('2013-02-11 14:19:00'),
                                        counter: 1,
                                        pipeline: pipeline
                            )
                           ]
    end
  end

  let (:older_green_pipeline) do
    OpenStruct.new(materials: older_materials, dependencies: older_dependencies).tap do |pipeline|
      pipeline.stages = [OpenStruct.new(
                            name: 'unit',
                            result: 'Passed',
                                        completed_at: Time.parse('2013-02-10 14:10:00'),
                                        pipeline: pipeline),
                         OpenStruct.new(
                             name: 'acceptance',
                             result: 'Passed',
                                        completed_at: Time.parse('2013-02-10 14:19:00',
                                                                 pipeline: pipeline))
                        ]
    end
  end

  let (:materials) do
    [OpenStruct.new(commits: [OpenStruct.new(revision: 'xyz456')], repository_url: 'http://go.bonito.org/git/repo')]
  end

  let (:older_materials) do
    [OpenStruct.new(commits: [OpenStruct.new(revision: 'abc123')], repository_url: 'http://go.bonito.org/git/repo')]
  end


  let(:dependencies) do
    [OpenStruct.new(pipeline_name: 'upstream-pipeline', stage_name: 'ready_for_prod', identifier: 'upstream-pipeline/11/ready_for_prod/2')]
  end

  let(:older_dependencies) do
    [OpenStruct.new(pipeline_name: 'upstream-pipeline', stage_name: 'ready_for_prod', identifier: 'upstream-pipeline/2/ready_for_prod/3')]
  end


end
