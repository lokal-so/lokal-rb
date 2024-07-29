# File: lib/lokal.rb

require 'json'
require 'faraday'
require 'semantic'
require 'colorize'

module Lokal
  class Client
    SERVER_MIN_VERSION = '0.6.0'

    attr_reader :base_url, :rest

    def initialize(options = {})
      @base_url = options[:base_url] || 'http://127.0.0.1:6174'
      @rest = Faraday.new(url: @base_url) do |faraday|
        faraday.request :url_encoded
        faraday.adapter Faraday.default_adapter
        faraday.headers['User-Agent'] = 'Lokal Ruby - github.com/lokal-so/lokal-ruby'
      end

      set_basic_auth(options[:username], options[:password]) if options[:username] && options[:password]
      set_api_token(options[:api_token]) if options[:api_token]

      @rest.response :raise_error
    end

    def set_base_url(url)
      @base_url = url
      @rest.url_prefix = url
      self
    end

    def set_basic_auth(username, password)
      @rest.basic_auth(username, password)
      self
    end

    def set_api_token(token)
      @rest.headers['X-Auth-Token'] = token
      self
    end

    def new_tunnel
      Tunnel.new(self)
    end

    private

    def check_server_version(response)
      server_version = response.headers['Lokal-Server-Version']
      return unless server_version

      if Semantic::Version.new(server_version) < Semantic::Version.new(SERVER_MIN_VERSION)
        raise "Your local client is outdated, please update to minimum version #{SERVER_MIN_VERSION}"
      end
    end
  end

  class Tunnel
    attr_accessor :lokal, :id, :name, :tunnel_type, :local_address, :server_id, :address_tunnel,
                  :address_tunnel_port, :address_public, :address_mdns, :inspect, :options,
                  :ignore_duplicate, :startup_banner

    def initialize(lokal)
      @lokal = lokal
      @options = Options.new
      @ignore_duplicate = false
      @startup_banner = false
    end

    def set_local_address(local_address)
      @local_address = local_address
      self
    end

    def set_tunnel_type(tunnel_type)
      @tunnel_type = tunnel_type
      self
    end

    def set_inspection(inspect)
      @inspect = inspect
      self
    end

    def set_lan_address(lan_address)
      @address_mdns = lan_address.chomp('.local')
      self
    end

    def set_public_address(public_address)
      @address_public = public_address
      self
    end

    def set_name(name)
      @name = name
      self
    end

    def ignore_duplicate
      @ignore_duplicate = true
      self
    end

    def show_startup_banner
      @startup_banner = true
      self
    end

    def create
      raise "Please enable either LAN address or random/custom public URL" if @address_mdns.empty? && @address_public.empty?

      response = @lokal.rest.post('/api/tunnel/start') do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = to_json
      end

      @lokal.send(:check_server_version, response)

      data = JSON.parse(response.body)
      raise data['message'] unless data['success']

      tunnel_data = data['data'].first
      update_attributes(tunnel_data)

      print_startup_banner if @startup_banner

      self
    rescue Faraday::ClientError => e
      handle_duplicate_error(e) if @ignore_duplicate
      raise
    end

    def get_lan_address
      raise "LAN address is not being set" if @address_mdns.empty?
      @address_mdns.end_with?('.local') ? @address_mdns : "#{@address_mdns}.local"
    end

    def get_public_address
      raise "Public address is not requested by client" if @address_public.empty?
      raise "Unable to assign public address" if @address_public.empty?

      if @tunnel_type != 'HTTP' && !@address_public.include?(':')
        update_public_url_port
        raise "Tunnel is using a random port, but it has not been assigned yet. Please try again later"
      end

      @address_public
    end

    private

    def to_json
      {
        name: @name,
        tunnel_type: @tunnel_type,
        local_address: @local_address,
        server_id: @server_id,
        address_tunnel: @address_tunnel,
        address_tunnel_port: @address_tunnel_port,
        address_public: @address_public,
        address_mdns: @address_mdns,
        inspect: @inspect,
        options: @options.to_h
      }.to_json
    end

    def update_attributes(data)
      data.each do |key, value|
        instance_variable_set("@#{key}", value) if respond_to?("#{key}=")
      end
    end

    def update_public_url_port
      response = @lokal.rest.get("/api/tunnel/info/#{@id}")
      @lokal.send(:check_server_version, response)

      data = JSON.parse(response.body)
      raise data['message'] unless data['success']

      tunnel_data = data['data'].first
      @address_public = tunnel_data['address_public'] if tunnel_data['address_public'].include?(':')
    end

    def handle_duplicate_error(error)
      return unless error.response.status == 409 # Assuming 409 is used for conflicts/duplicates

      data = JSON.parse(error.response.body)
      tunnel_data = data['data'].first
      update_attributes(tunnel_data)
      show_startup_banner if @startup_banner
    end

    def print_startup_banner
      banner = <<-BANNER
    __       _         _             
   / /  ___ | | ____ _| |  ___  ___  
  / /  / _ \\| |/ / _  | | / __|/ _ \\ 
 / /__| (_) |   < (_| | |_\\__ \\ (_) |
 \\____/\\___/|_|\\_\\__,_|_(_)___/\\___/
      BANNER

      colors = [:magenta, :blue, :cyan, :green, :red]
      banner_lines = banner.split("\n")
      banner_lines.each_with_index do |line, index|
        puts line.colorize(colors[index % colors.length])
      end

      puts
      puts "Minimum Lokal Client".colorize(:red) + "\t" + Lokal::Client::SERVER_MIN_VERSION
      puts "Public Address".colorize(:cyan) + "\t\thttps://#{@address_public}" if @address_public.length > 0
      puts "LAN Address".colorize(:green) + "\t\thttps://#{get_lan_address}" if @address_mdns.length > 0
      puts
    end
  end

  class Options
    attr_accessor :basic_auth, :cidr_allow, :cidr_deny, :request_header_add, :request_header_remove,
                  :response_header_add, :response_header_remove, :header_key

    def initialize
      @basic_auth = []
      @cidr_allow = []
      @cidr_deny = []
      @request_header_add = []
      @request_header_remove = []
      @response_header_add = []
      @response_header_remove = []
      @header_key = []
    end

    def to_h
      instance_variables.each_with_object({}) do |var, hash|
        hash[var.to_s.delete('@')] = instance_variable_get(var)
      end
    end
  end
end
