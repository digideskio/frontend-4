# encoding: utf-8
require "test_helper"

class SearchControllerTest < ActionController::TestCase
  def stub_client
    mainstream_client = stub("search", search: [])
    Frontend.stubs(:mainstream_search_client).returns(mainstream_client)
    detailed_client = stub("search", search: [])
    Frontend.stubs(:detailed_guidance_search_client).returns(detailed_client)
  end

  setup do
    stub_client
  end

  test "should ask the user to enter a search term if none was given" do
    get :index, q: ""
    assert_select "label", %{What are you looking for?}
    assert_select "form[action=?]", search_path do
      assert_select "input[name=q]"
    end
  end

  test "should inform the user that we didn't find any documents matching the search term" do
    get :index, q: "search-term"
    assert_select "p", text: %Q{Please try another search in the search box at the top of the page.}
  end

  test "should pass our query parameter in to the search client" do
    Frontend.mainstream_search_client.expects(:search).with("search-term", nil).returns([]).once
    get :index, q: "search-term"
  end

  test "should include link to JSON version in HTML header" do
    Frontend.mainstream_search_client.stubs(:search).returns([{}, {}, {}])
    get :index, q: "search-term"
    assert_select 'head link[rel=alternate]' do |elements|
      assert elements.any? { |element|
        element['href'] == '/api/search.json?q=search-term'
      }
    end
  end

  test "should display the number of results" do
    Frontend.mainstream_search_client.stubs(:search).returns([{}, {}, {}])
    get :index, q: "search-term"
    assert_select "label", text: /3 results for/
  end

  test "should display correct count for combined results" do
    Frontend.mainstream_search_client.stubs(:search).returns([{}, {}, {}])
    Frontend.detailed_guidance_search_client.stubs(:search).returns([{}])
    get :index, q: "search-term"
    assert_select "label", text: /4 results for/
  end

  test "should use correct pluralisation for a single result" do
    Frontend.mainstream_search_client.stubs(:search).returns([{}])
    get :index, q: "search-term"
    assert_select "label", text: /1 result for/
  end

  test "should only count non-recommended results in total" do
    Frontend.mainstream_search_client.stubs(:search).returns(Array.new(45, {}) + Array.new(20, {format: 'recommended-link'}))
    get :index, q: "search-term"
    assert_select "label", text: /45 results for/
  end

  test "should display just tab page of results if we have results from a single index" do
    Frontend.mainstream_search_client.stubs(:search).returns([{}, {}, {}])
    Frontend.detailed_guidance_search_client.stubs(:search).returns([])
    get :index, q: "search-term"
    assert_select 'nav.js-tabs', count: 0
  end

  test "should display tabs when there are mixed results" do
    Frontend.mainstream_search_client.stubs(:search).returns([{}, {}, {}])
    Frontend.detailed_guidance_search_client.stubs(:search).returns([{}])
    get :index, q: "search-term"
    assert_select "nav.js-tabs"
  end

  test "should display index count on respective tab" do
    Frontend.mainstream_search_client.stubs(:search).returns([{}, {}, {}])
    Frontend.detailed_guidance_search_client.stubs(:search).returns([{}])
    get :index, q: "search-term"
    assert_select "a[href='#mainstream-results']", text: "Results (3)"
    assert_select "a[href='#detailed-results']", text: "Detailed guidance (1)"
  end

  test "should display a link to the documents matching our search criteria" do
    client = stub("search", search: [{"title" => "document-title", "link" => "/document-slug"}])
    Frontend.stubs(:mainstream_search_client).returns(client)
    get :index, q: "search-term"
    assert_select "a[href='/document-slug']", text: "document-title"
  end

  test "should set the class of the result according to the format" do
    client = stub("search", search: [{"title" => "title", "link" => "/slug", "highlight" => "", "format" => "publication"}])
    Frontend.stubs(:mainstream_search_client).returns(client)
    get :index, q: "search-term"
    assert_select ".results-list .type-publication"
  end

  test "should_not_blow_up_with_a_result_wihout_a_section" do
    result_without_section = {
      "title" => "TITLE1",
      "description" => "DESCRIPTION",
      "link" => "/URL"
    }
    Frontend.mainstream_search_client.stubs(:search).returns([result_without_section])
    assert_nothing_raised do
      get :index, {q: "bob"}
    end
  end

  test "should include sections in results" do
    result_with_section = {
      "title" => "TITLE1",
      "description" => "DESCRIPTION",
      "link" => "/url",
      "section" => "life-in-the-uk",
    }
    Frontend.mainstream_search_client.stubs(:search).returns([result_with_section])
    get :index, {q: "bob"}

    assert_select '.result-meta li', text: "Life in the UK"
  end

  test "should return unlimited results" do
    Frontend.mainstream_search_client.stubs(:search).returns(Array.new(75, {}))

    get :index, q: "Test"

    assert_equal 75, assigns[:primary_results].length
  end

  test "should show the phrase searched for" do
    Frontend.mainstream_search_client.stubs(:search).returns(Array.new(75, {}))

    get :index, q: "Test"

    assert_select 'input[value=Test]'
  end

  test "should split mainstream into internal and external" do
    Frontend.mainstream_search_client.stubs(:search).returns(Array.new(45, {}) + Array.new(20, {format: 'recommended-link'}))

    get :index, q: "Test"

    assert_equal 45, assigns[:primary_results].length
    assert_equal 20, assigns[:external_link_results].length
  end

  test "should_show_external_links_with_a_separate_list_class" do
    external_document = {
      "title" => "A title",
      "description" => "This is a description",
      "link" => "http://twitter.com",
      "section" => "driving",
      "format" => "recommended-link"
    }

    Frontend.mainstream_search_client.stubs(:search).returns([external_document])

    get :index, {q: "bleh"}
    assert_select ".external-links li.external" do
      assert_select "a[rel=external]", "A title"
    end
  end

  test "should show external links in a separate column" do
    external_document = {
      "title" => "A title",
      "description" => "This is a description",
      "link" => "http://twitter.com",
      "section" => "driving",
      "format" => "recommended-link"
    }

    Frontend.mainstream_search_client.stubs(:search).returns([external_document])

    get :index, {q: "bleh"}
    assert_select ".external-links li.external" do
      assert_select "a[rel=external]", "A title"
    end
    assert_select '.internal-links li.external', count: 0
  end

  test "should send analytics headers for citizen proposition" do
    get :index, {q: "bob"}
    assert_equal "search",  response.headers["X-Slimmer-Section"]
    assert_equal "search",  response.headers["X-Slimmer-Format"]
    assert_equal "citizen", response.headers["X-Slimmer-Proposition"]
    assert_equal "0",       response.headers["X-Slimmer-Result-Count"]
  end

  test "result count header with results" do
    Frontend.mainstream_search_client.stubs(:search).returns(Array.new(15, {}))

    get :index, {q: "bob"}

    assert_equal "15", response.headers["X-Slimmer-Result-Count"]
  end
end