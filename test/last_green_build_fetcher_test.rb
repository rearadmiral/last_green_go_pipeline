require_relative '../lib/last_green_build_fetcher'
require 'ostruct'

class LastGreenBuilderFetcherTest < Minitest::Test

  def test_fetch_with_no_green_builds_returns_nil
    failing_pipeline = OpenStruct.new
      passing_units = OpenStruct.new(:name => 'unit', :result => 'Passed', :completed_at => Time.parse('2013-02-10 11:40:00'))
      failing_acceptance = OpenStruct.new(:name => 'acceptance', :result => 'Failed', :completed_at => Time.parse('2013-02-10 11:45:00'))
    failing_pipeline.stages = [passing_units, failing_acceptance]
    with_go_api_client_returning({:pipelines => [failing_pipeline], :latest_atom_entry_id => 'ignore'}) do
      fetcher = LastGreenBuildFetcher.new({:stage_name => 'acceptance'})
      assert_equal nil, fetcher.fetch
    end
  end

  def test_fetching_writes_latest_atom_entry_id_persistently
    with_go_api_client_returning({:pipelines => [], :latest_atom_entry_id => 'ABC123'}) do
      fetcher = LastGreenBuildFetcher.new({ :pipeline_name => 'pipeline' })
      fetcher.fetch
      cache = PStore.new(@cache_filename)
      assert_equal 'ABC123', cache.transaction(true) { cache['pipeline'][:latest_atom_entry_id] }
    end
  end

  def test_fetch_will_use_latest_atom_entry_id_file_if_it_exists
    cache = PStore.new(@cache_filename)
    cache.transaction { cache['XYZ'] = { latest_atom_entry_id: 'http://go01.thoughtworks.com/feed/pipeline/XYZ/123.xml' }; cache.commit; }
    with_go_api_client_returning({:pipelines => [], :latest_atom_entry_id => 'http://go01.thoughtworks.com/feed/pipeline/XYZ/124.xml'}) do
      LastGreenBuildFetcher.new({ :pipeline_name => 'XYZ'}).fetch
      assert_equal "http://go01.thoughtworks.com/feed/pipeline/XYZ/123.xml", @@mock_param_value[:latest_atom_entry_id]
    end
  end

  def test_second_fetch_with_no_new_results_returns_last_known_time
    mock_pipeline = OpenStruct.new(:name => 'XYZ')
    passing_units = OpenStruct.new(:name => 'unit', :result => 'Passed', :completed_at => Time.parse('2013-02-10 11:40:00'))
    mock_pipeline.stages = [passing_units]
    fetcher = LastGreenBuildFetcher.new({:pipeline_name => 'XYZ', :stage_name => 'unit'})
    with_go_api_client_returning({:pipelines => [mock_pipeline], :latest_atom_entry_id => ''}) do
      assert_equal Time.parse('2013-02-10 11:40:00'), fetcher.fetch
    end
    with_go_api_client_returning({:pipelines => [], :latest_atom_entry_id => ''}) do
      assert_equal Time.parse('2013-02-10 11:40:00'), fetcher.fetch
    end
  end

  def test_fetching_empty_pipelines_returns_nil
     with_go_api_client_returning({:pipelines => [], :latest_atom_entry_id => ''}) do
      fetcher = LastGreenBuildFetcher.new({})
      assert_equal nil, fetcher.fetch
    end
  end


end
