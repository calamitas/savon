module Savon

  # == Savon::Response
  #
  # Represents the HTTP and SOAP response.
  class Response

    # The global setting of whether to raise errors.
    @@raise_errors = true

    # Sets the global setting of whether to raise errors.
    def self.raise_errors=(raise_errors)
      @@raise_errors = raise_errors
    end

    # Returns the global setting of whether to raise errors.
    def self.raise_errors?
      @@raise_errors
    end
    
    # Sets a specific handler for errors to raise.
    def self.error_handler(&blk)
      @@error_handler = blk
    end

    # Expects a Net::HTTPResponse and handles errors.
    def initialize(http)
      @http = http

      handle_soap_fault
      handle_http_error
    end

    # Returns whether there was a SOAP fault.
    def soap_fault?
      @soap_fault ? true : false
    end
    
    # Returns the SOAP fault message.
    attr_reader :soap_fault
    
    # Returns the SOAP error code
    attr_reader :soap_error_code

    # Returns whether there was an HTTP error.
    def http_error?
      @http_error ? true : false
    end

    # Returns the HTTP error message.
    attr_reader :http_error

    # Returns the SOAP response body as a Hash.
    def to_hash
      @body ||= (Crack::XML.parse(@http.body) rescue {}).find_soap_body
    end

    # Returns the SOAP response XML.
    def to_xml
      @http.body
    end

    # Returns the HTTP response object.
    attr_reader :http
    
    alias :to_s :to_xml

  private

    # Handles SOAP faults. Raises a Savon::SOAPFault unless the default
    # behavior of raising errors was turned off.
    def handle_soap_fault
      if soap_fault_message
        @soap_fault = soap_fault_message
        @soap_error_code = Integer(((to_hash[:fault] || {})[:detail] || {})[:errorcode] || 0)
        raise Savon::SOAPFault.new(@soap_fault, @soap_error_code) if self.class.raise_errors?
      end
    end

    # Returns a SOAP fault message in case a SOAP fault was found.
    def soap_fault_message
      @soap_fault_message ||= soap_fault_message_by_version to_hash[:fault]
    end

    # Expects a Hash that might contain information about a SOAP fault.
    # Returns the SOAP fault message in case one was found.
    def soap_fault_message_by_version(soap_fault)
      return unless soap_fault
      
      if @@error_handler
        @@error_handler.call(soap_fault)
      else
        if soap_fault.keys.include? :faultcode
          "(#{soap_fault[:faultcode]}) #{soap_fault[:faultstring]}"
        elsif soap_fault.keys.include? :code
          "(#{soap_fault[:code][:value]}) #{soap_fault[:reason][:text]}"
        end
      end
    end

    # Handles HTTP errors. Raises a Savon::HTTPError unless the default
    # behavior of raising errors was turned off.
    def handle_http_error
      if @http.code.to_i >= 300
        @http_error = "#{@http.message} (#{@http.code})"
        @http_error << ": #{@http.body}" unless @http.body.empty?
        raise Savon::HTTPError.new(http_error, @http.to_hash) if self.class.raise_errors?
      end
    end

  end
end
