class TravelAdviceController < ApplicationController
  before_filter(only: [:country]) { validate_slug_param(:country_slug) }
  before_filter(only: [:country]) { validate_slug_param(:part) if params[:part] }

  def index
    set_expiry

    response = content_store.content_item("/foreign-travel-advice")
    content_item = response.to_hash
    merge_hardcoded_breadcrumbs!(content_item)

    @presenter = TravelAdviceIndexPresenter.new(content_item)
    set_slimmer_artefact_headers(content_item, format: "travel-advice")

    respond_to do |format|
      format.html { render locals: { full_width: true } }
      format.atom { set_expiry(5.minutes) }
      # TODO: Doing a static redirect to the API URL here means that an API call
      #       and a variety of other logic will have been executed unnecessarily.
      #       We should move this to the top of the method or out to routes.rb for
      #       efficiency.
      format.json { redirect_to "/api/foreign-travel-advice.json" }
    end
  end

  def country
    set_expiry(5.minutes)

    @country = params[:country_slug].dup
    @edition = params[:edition]

    @publication = fetch_publication_for_country(@country)

    tags = @publication.artefact.to_hash["tags"]
    section_tag = tags.find {|t| t["details"]["type"] == "section" }

    combined_tags = slimmer_section_tag_for_details(
      section_name: "Foreign travel advice",
      section_link: "/foreign-travel-advice"
    ).merge("parent" => section_tag)

    if section_tag.present?
      tags[tags.index(section_tag)] = combined_tags
    else
      tags << combined_tags
    end

    set_slimmer_artefact_headers(@publication.artefact.to_hash.merge('tags' => tags))

    I18n.locale = :en # These pages haven't been localised yet.

    if params[:part].present?
      @publication.current_part = params[:part]
      unless @publication.current_part
        redirect_to(travel_advice_country_path(@country)) && return
      end
    end

    request.variant = :print if params[:variant].to_s == "print"

    respond_to do |format|
      format.atom
      format.html.none
      format.html.print do
        set_slimmer_headers template: "print"
        render layout: "application.print"
      end
    end
  rescue RecordNotFound
    error 404
  end

  private

  def fetch_publication_for_country(country)
    artefact = fetch_artefact("foreign-travel-advice/" + country, params[:edition])
    TravelAdviceCountryPresenter.new(artefact)
  end

  # This will soon be replaced by:
  #
  # https://trello.com/c/tomHUlp7/475-define-data-format-for-breadcrumbs
  # https://trello.com/c/vm54jvVo/477-send-hard-coded-breadcrumbs-to-publishing-api
  def merge_hardcoded_breadcrumbs!(content_item)
    content_item.merge!(
      "tags" => [{
          "title" => "Travel abroad",
          "web_url" => "/browse/abroad/travel-abroad",
          "details" => { "type" => "section" },
          "content_with_tag" => { "web_url" => "/browse/abroad/travel-abroad" },
          "parent" => {
            "web_url" => "/browse/abroad",
            "title" => "Passports, travel and living abroad",
            "details" => { "type" => "section" },
            "content_with_tag" => { "web_url" => "/browse/abroad" },
            "parent" => nil,
          },
      }]
    )
  end
end
