require "net_http_hacked"
require "stringio"

module Rack

  # Wraps the hacked net/http in a Rack way.
  class HttpStreamingResponse
    STATUSES_WITH_NO_ENTITY_BODY = [204, 205, 304].freeze

    attr_accessor :use_ssl
    attr_accessor :verify_mode
    attr_accessor :read_timeout
    attr_accessor :ssl_version

    def initialize(request, host, port = nil)
      @request, @host, @port = request, host, port
    end

    def body
      self
    end

    def code
      response.code.to_i.tap do |response_code|
        close_connection if STATUSES_WITH_NO_ENTITY_BODY.include?(response_code)
      end
    end
    # #status is deprecated
    alias_method :status, :code

    def headers
      Utils::HeaderHash.new.tap do |h|
        response.to_hash.each { |k, v| h[k] = v }
      end
    end

    # Can be called only once!
    def each(&block)
      return if connection_closed

      response.read_body(&block)
    ensure
      return if connection_closed

      session.end_request_hacked
      session.finish
    end

    def to_s
      @to_s ||= StringIO.new.tap { |io| each { |line| io << line } }.string
    end

    protected

    # Net::HTTPResponse
    def response
      @response ||= session.begin_request_hacked(request)
    end

    # Net::HTTP
    def session
      @session ||= Net::HTTP.new(host, port).tap do |http|
        http.use_ssl = use_ssl
        http.verify_mode = verify_mode
        http.read_timeout = read_timeout
        http.ssl_version = ssl_version if use_ssl
        http.start
      end
    end

    private

    attr_reader :request, :host, :port

    attr_accessor :connection_closed

    def close_connection
      self.connection_closed = true
      session.end_request_hacked
      session.finish
    end
  end
end
