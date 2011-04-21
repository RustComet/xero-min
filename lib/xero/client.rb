require 'oauth'
require 'oauth/signature/rsa/sha1'
require 'oauth/request_proxy/typhoeus_request'
require 'typhoeus'
require 'yajl'
require 'active_support/core_ext/hash/conversions'

module Xero
  class Client
    # all requests return hash or array, as would parsed json
    #
    # xero api does not support to return json content in POST | PUT !!!
    #
    # hence, activesupport to parse xml as a hash ...
    # terrible
    #
    @@signature = {
      signature_method: 'RSA-SHA1',
      private_key_file: '/Users/thenrio/src/ruby/agile-france-program-selection/keys/xero.rsa'
    }
    @@options = {
      site: 'https://api.xero.com/api.xro/2.0',
      request_token_path: "/oauth/RequestToken",
      access_token_path: "/oauth/AccessToken",
      authorize_path: "/oauth/Authorize",
    }.merge(@@signature)

    attr_writer :token
    attr_accessor :verbose

    def initialize(consumer_key=nil, secret_key=nil, options={})
      self.verbose = true
      @options = @@options.merge(options)
      @consumer_key, @secret_key  = consumer_key || 'YZJMNTAXYTBJMTYZNGFMMZK0ODGZMW', secret_key || 'WLIHEJM3AJSNFL12M5LXZVB9S9XYX9'
    end

    def token
      @token ||= OAuth::AccessToken.new(OAuth::Consumer.new(@consumer_key, @secret_key, @options),
        @consumer_key, @secret_key)
    end

    # Public : post given xml to invoices url
    # default method is put
    # yields request to block if present
    # returns parsed jsoned
    def post_invoice(xml, options={}, &block)
      r = request('https://api.xero.com/api.xro/2.0/Invoice', {method: :put, body: xml}.merge(options), &block)
      queue(r).run
      parse! r.response
    end

    # Public : post given xml to contacts url
    # default method is put
    # yields request to block if present
    def post_contact(xml, options={}, &block)
      r = request('https://api.xero.com/api.xro/2.0/Contact', {method: :put, body: xml}.merge(options), &block)
      queue(r).run
      parse r.response
    end

    # get contacts
    def get_contacts(options={}, &block)
      r = request('https://api.xero.com/api.xro/2.0/Contacts',
        {headers: {'Accept' => 'application/json'}}.merge(options), &block)
      queue(r).run
      parse! r.response
    end

    def request(uri, options={}, &block)
      req = Typhoeus::Request.new(uri, options)
      helper = OAuth::Client::Helper.new(req, @@signature.merge(consumer: token.consumer, token: token, request_uri: uri))
      req.headers.merge!({'Authorization' => helper.header})
      yield req if block_given?
      req
    end

    # return parsed json
    def parse(response)
       json?(response) ? Yajl::Parser.new.parse(response.body) : Hash.from_xml(response.body)
    end

    def json?(response)
      response.headers['Accept'] == 'application/json'
    end

    # parse response or die unless code is success
    def parse!(response)
      body = parse(response)
      response.success?? body : raise(Problem, body)
    end

    def queue(request)
      hydra.queue(request)
      self
    end

    def run
      hydra.run
    end

    private
    def hydra
      @hydra ||= Typhoeus::Hydra.new
    end
  end
  class Problem < StandardError
  end
end