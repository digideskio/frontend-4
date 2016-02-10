module CampaignHelper
  CUSTOM_LOGO_ORGANISATIONS = %w{
    environment-agency
  }

  def campaign_image_url(publication, size)
    if image_attrs = publication.details["#{size}_image"]
      image_attrs['web_url']
    end
  end

  def organisation_name(publication)
    organisation_attributes(publication).fetch("formatted_name", "").gsub(/\s+/, ' ')
  end

  def formatted_organisation_name(publication)
    organisation_name = organisation_attributes(publication).fetch("formatted_name", "")
    ERB::Util.html_escape(organisation_name).strip.gsub(/(?:\r?\n)/, "<br/>").html_safe
  end

  def organisation_url(publication)
    organisation_attributes(publication)["url"]
  end

  def organisation_slug(publication)
    organisation_url(publication).split('/').last
  end

  def organisation_crest(publication)
    organisation_attributes(publication)["crest"]
  end

  def organisation_brand_colour(publication)
    organisation_attributes(publication)["brand_colour"]
  end

  def has_organisation?(publication)
    organisation_attributes(publication).any? { |_key, value|
      value.present?
    }
  end

  def organisation_has_custom_logo?(publication)
    CUSTOM_LOGO_ORGANISATIONS.include? organisation_slug(publication)
  end

private
  def organisation_attributes(publication)
    publication.details.fetch("organisation", {})
  end
end
