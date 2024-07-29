# Lokal Ruby

Ruby Gem for interacting with Lokal Client REST API.

[![Gem Version](https://badge.fury.io/rb/lokal.svg)](https://badge.fury.io/rb/lokal)

![screenshot cli](screenshot1.png)
![screenshot address bar](screenshot2.png)

## Installation

```ruby
gem 'lokal', '~> 0.0.1'
```

or install globally

```sh
gem install lokal
```

## Example Usage

```ruby
require 'lokal'
require 'sinatra'

client = Lokal::Client.new
tunnel = client.new_tunnel
           .set_name("Sinatra Backend")
           .set_tunnel_type("HTTP")
           .set_local_address("4567")
           # self-hosted tunnel server with domain k.lokal-so.site must be exist or using Lokal Cloud
           .set_public_address("mybackend551.k.lokal-so.site")
           .set_lan_address("sinatra1.local")
           .ignore_duplicate()
           .show_startup_banner

tunnel.create

configure do
  set :port, 4567
end

get '/' do
  'Hello world!'
end
```
