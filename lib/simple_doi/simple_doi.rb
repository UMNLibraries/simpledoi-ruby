require 'json'
require 'cgi'
require 'uri'

# A simple DOI handling library
# Capable of validating DOIs and retrieving metadata
module SimpleDOI
  CITEPROC_JSON = 'application/vnd.citationstyles.csl+json'
  UNIXREF_XML = 'application/vnd.crossref.unixref+xml'

  # Regex pattern NOT anchored with ^$
  # Validation will add anchors
  # DOI_PATTERN = '\b(10\.[\d]{4,}(?:\.[\d]+)*\/(?:(?!["&\'<>])[[:graph:]])+)\b'
  DOI_PATTERN = '\b(10\.[\d]+(?:\.[\d]+)*\/(?:(?!["&\'])[[:graph:]])+)\b?'

  STRIP_PATTERNS = [
    /\/(abstract|asset|issuetoc).*$/,
    /\.pdf$/,
    /\/(standard|pdf\/standard|fulltext\.html|pdf|epdf|meta|full|dynaTraceMonitor|references|issues|full)$/,
    /\/cite\/[a-z]+$/,
    /;jsessionid.+$/
  ].freeze

  # Convenience methods to call directly on module
  def valid?(doi)
    !!(strip(doi) =~ Regexp.new('^' + DOI_PATTERN + '$'))
  end

  # Attempt to extract all DOIs from string
  # Returns an array of SimpleDOI::DOI objects
  def extract(string)
    string = CGI.unescape string
    list = (string.scan(Regexp.new(DOI_PATTERN))).flatten
    # Calls strip() to make sure nothing like ?nosfx=y remains
    list.map! { |doi| strip doi }

    dois = []
    list.each { |doi| dois.push(SimpleDOI::DOI.new(doi)) if valid?(doi) }
    dois
  end

  # Strip off dx.doi.org extra stuff
  def strip(string)
    # Strip off leading DOI: if present
    string.sub!(/^doi:/i, '')

    # Strip off doi.org URL prefix and ?nosfx
    string.sub!(Regexp.new('^https?://' + DOI::LOOKUP_URL_DOMAIN + '/'), '')

    # Strip query string
    # Have to make sure it actually looks like a query string with key=value
    # because ? are not expressly prohibited in a DOI.
    string.sub!(/\?[^=]+=.*/, '')

    # Strip trailing /
    string.sub!(/\/$/, '')

    # Aggressively strip known URL patterns which tend not to be part
    STRIP_PATTERNS.each { |pattern| string.sub!(pattern, '') }

    string
  end
  module_function :valid?, :extract, :strip

  # Represents a DOI object capable of being resolved to a target URL or
  # full metadata retrieved.
  class DOI
    include SimpleDOI

    LOOKUP_URL_DOMAIN = 'dx.doi.org'

    BACKENDS = %w(curb net/http)

    REDIR_CODES = [301, 302, 303]

    READ_TIMEOUT = 10

    attr_reader :body, :response_content_type, :response_code, :backend, :doi

    def initialize(doi)
      # Prefer curb if available, otherise Net::HTTP
      @backend = 'curb' if defined?(Curl)
      @backend ||= 'net/http' if defined?(Net::HTTP)

      raise ArgumentError, "Supplied string does not appear to be a valid DOI: #{doi}" unless valid?(doi)
      @doi = doi
      @target_url = nil
    end

    def to_s
      @doi
    end

    def backend=(backend)
      if BACKENDS.include? backend
        @backend = backend
        require backend
      else
        raise ArgumentError, "Only '#{BACKENDS.join("', '")}' are supported"
      end
    end

    def prefix
      to_s.split('/').first
    end

    def suffix
      to_s.split('/', 2).last
    end

    # Return an ISSN string if the DOI suffix matches:
    # j.1234-567X
    # issn.1234-567X
    # 1234-567X.otherstuff
    # ScienceDirect prefixes with S
    # S1234-567X(otherstuff)
    # (ISSN)1234-567X.otherstuff
    def issn
      suffix.scan(/^(?:(?:j\.|issn\.)|S|\(ISSN\))?(\d{4}-\d{3}[\dx])\b/i).flatten.first
    end

    # Perform a lookup for DOI metadata, requesting content types
    # specified in accept
    # Returns: +String+ HTTP response body
    # Params:
    # * +accept+:: +String|Array+ Requested Accept: content types may be single string or array
    def lookup(accept = CITEPROC_JSON)
      raise NoBackendError unless @backend

      # Coerce accept to a 1D array
      accept = [accept].flatten
      @body = nil
      @response_content_type = nil
      @response_code = nil

      case @backend
      when 'curb'
        client = Curl::Easy.new(url) do |request|
          request.headers['Accept'] = accept.join(', ')
          request.follow_location = true
        end
        client.perform
        @response_code = client.response_code.to_i
        if @response_code == 200
          @body = client.body_str
          # Curl returns all headers a string block
          # We only need Content-Type
          # The *last* Content-Type from redirection is the relevant one
          @response_content_type = client.header_str.scan(/content-type:\s+(\S+)/i).flatten.pop rescue nil
        end
      when 'net/http'
        uri = URI.parse url

        response = net_http_response_redirect(uri, accept)
        @response_code = response.code.to_i
        if @response_code == 200
          @body = response.body
          @response_content_type = response['content-type']
        end
      end

      # Raise an error if the document ultimately retrieved doesn't have a JSON or XML
      # content type.
      # We've seen some JSTOR documents redirect 3+ times and return a 200 with HTML
      # instead of the requested metadata - basically ignored content negotiation.
      if @response_code == 200 && @response_content_type !~ /json|xml/
        raise InvalidResponseContentTypeError
      end
      @body
    end

    def lookup_xml
      lookup UNIXREF_XML
    end

    def lookup_json
      resp = lookup CITEPROC_JSON
      JSON.parse(resp) unless resp.nil?
    end

    def self.lookup_url_root
      "https://#{LOOKUP_URL_DOMAIN}/"
    end

    # Get the redirection target URL or return it if already retrieved
    def target_url
      return @target_url unless @target_url.nil?

      # Perform an HTTP request but don't follow the first redirect
      case @backend
      when 'curb'
        client = Curl::Easy.new(url) do |c|
          c.max_redirects = 0
          c.follow_location = false
          c.timeout = READ_TIMEOUT
        end
        client.perform
        location = client.header_str.scan(/location:\s+(\S+)/i).flatten.first if REDIR_CODES.include? client.response_code.to_i
      when 'net/http'
        uri = URI.parse url
        request_use_ssl = uri.scheme == 'https'
        client = Net::HTTP.new uri.host, (request_use_ssl ? Net::HTTP.https_default_port : Net::HTTP.http_default_port)
        client.use_ssl = request_use_ssl
        request = Net::HTTP::Get.new uri.request_uri
        response = client.request request
        location = response['location'] if REDIR_CODES.map(&:to_s).include? response.code
      end
      @target_url = location
    end

    def url
      "#{self.class.lookup_url_root}#{CGI.escape(to_s)}"
    end

    protected

    def net_http_response_redirect(uri, type)
      # Net::HTTP require different initial setup for https vs http
      request_use_ssl = uri.scheme == 'https'
      client = Net::HTTP.new uri.host, (request_use_ssl ? Net::HTTP.https_default_port : Net::HTTP.http_default_port)
      client.use_ssl = request_use_ssl
      client.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Get.new uri.request_uri
      request['Accept'] = type
      response = client.request request

      # Recurse until done redirecting
      if REDIR_CODES.map(&:to_s).include? response.code
        net_http_response_redirect(URI.parse(response['location']), type)
      else
        response
      end
    end
  end

  class DOIError < StandardError; end
  class InvalidResponseContentTypeError < DOIError; end

  # Raised when no supported HTTP client backend was found in the constant space
  class NoBackendError < DOIError
    def initialize(msg = "No supported backend was found. You must require either 'curb' or 'net/http'")
      super msg
    end
  end
end
