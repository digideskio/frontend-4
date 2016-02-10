require 'gds_api/helpers'
require 'gds_api/content_api'

class RecordNotFound < StandardError
end

require 'artefact_retriever'

class ApplicationController < ActionController::Base
  protect_from_forgery
  include GdsApi::Helpers
  include Slimmer::Headers
  include Slimmer::Template
  include Slimmer::SharedTemplates

  rescue_from GdsApi::TimedOutException, with: :error_503
  rescue_from GdsApi::EndpointNotFound, with: :error_503
  rescue_from GdsApi::HTTPErrorResponse, with: :error_503
  rescue_from ArtefactRetriever::RecordArchived, with: :error_410
  rescue_from ArtefactRetriever::UnsupportedArtefactFormat, with: :error_404

  slimmer_template 'wrapper'

protected
  def error_404; error 404; end

  def error_410; error 410; end

  def error_503(e); error(503, e); end

  def error(status_code, exception = nil)
    if exception && defined? Airbrake
      env["airbrake.error_id"] = notify_airbrake(exception)
    end
    render status: status_code, text: "#{status_code} error"
  end

  def cacheable_404
    set_expiry(10.minutes)
    error 404
  end

  def statsd
    @statsd ||= Statsd.new("localhost").tap do |c|
      c.namespace = ENV['GOVUK_STATSD_PREFIX'].to_s
    end
  end

  def set_content_security_policy
    return unless Frontend::Application.config.enable_csp

    asset_hosts = "#{Plek.current.find('static')} #{Plek.current.asset_root}"

    # Our Content-Security-Policy directives use 'unsafe-inline' for scripts and
    # styles because current browsers (Chrome 39 and Firefox 35) only support the
    # CSP 1 spec, which does not provide support for whitelisting assets with
    # hash digests.

    default_src = "default-src #{asset_hosts}"
    script_src = "script-src #{asset_hosts} *.google-analytics.com 'unsafe-inline'"
    style_src = "style-src #{asset_hosts} 'unsafe-inline'"
    img_src = "img-src #{asset_hosts} *.google-analytics.com"
    font_src = "font-src #{asset_hosts} data:"
    report_uri = "report-uri #{Plek.current.website_root}/e"

    csp_header = "#{default_src}; #{script_src}; #{style_src}; #{img_src}; #{font_src}; #{report_uri}"

    headers['Content-Security-Policy-Report-Only'] = csp_header
  end

  def set_expiry(duration = 30.minutes)
    expires_in(duration, public: true) unless Rails.env.development?
  end

  def set_slimmer_artefact_headers(artefact, slimmer_headers = {})
    slimmer_headers[:format] ||= artefact["format"]
    set_slimmer_headers(slimmer_headers)
    if artefact["format"] == "help_page"
      set_slimmer_artefact_overriding_section(artefact, section_name: "Help", section_link: "/help")
    else
      set_slimmer_artefact(artefact)
    end
  end

  def fetch_artefact(slug, edition = nil, snac = nil, location = nil)
    ArtefactRetriever.new(content_api, Rails.logger, statsd).
      fetch_artefact(slug, edition, snac, location)
  end

  def content_api
    @content_api ||= GdsApi::ContentApi.new(
      Plek.current.find("contentapi"),
      content_api_options
    )
  end

  def content_store
    @content_store ||= GdsApi::ContentStore.new(
      Plek.current.find("content-store")
    )
  end

  def validate_slug_param(param_name = :slug)
    param_to_use = params[param_name].sub(/(done|help)\//, '')
    cacheable_404 if param_to_use.parameterize != param_to_use
  rescue StandardError # Triggered by trying to parameterize malformed UTF-8
    cacheable_404
  end

private
  def content_api_options
    options = CONTENT_API_CREDENTIALS
    unless request.format == :atom
      options = options.merge(web_urls_relative_to: Plek.current.website_root)
    end
    options
  end
end
