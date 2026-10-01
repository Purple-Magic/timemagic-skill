#!/usr/bin/env ruby
# frozen_string_literal: true

# Minimal TimeMagic API request wrapper. Stdlib only — no gems required.
#
# Usage:
#   ruby timemagic_request.rb GET  /api/projects
#   ruby timemagic_request.rb POST /api/projects '{"project":{"name":"New project"}}'
#   TIMEMAGIC_HOST=https://time-app.purple-magic.com ruby timemagic_request.rb GET /api/tasks/tracking
#
# Reads the token from TIMEMAGIC_API_TOKEN. Never pass the token as an argument
# (it would land in shell history / process listings).

require 'net/http'
require 'uri'
require 'json'

def fail_with(message)
  warn message
  exit 1
end

token = ENV['TIMEMAGIC_API_TOKEN']
if token.nil? || token.empty?
  fail_with(<<~MSG)
    TIMEMAGIC_API_TOKEN is not set.
    Get a token at #{ENV.fetch('TIMEMAGIC_HOST', 'https://time-app.purple-magic.com')}/docs/api
    (log in, then "API Token" section -> Regenerate token), then:
      export TIMEMAGIC_API_TOKEN=<token>
  MSG
end

method, path, body = ARGV
fail_with("Usage: #{$PROGRAM_NAME} METHOD /api/path ['{\"json\":\"body\"}']") unless method && path

host = ENV.fetch('TIMEMAGIC_HOST', 'https://time-app.purple-magic.com')
uri = URI.join(host, path)

request_class = {
  'GET' => Net::HTTP::Get,
  'POST' => Net::HTTP::Post,
  'PUT' => Net::HTTP::Put,
  'PATCH' => Net::HTTP::Patch,
  'DELETE' => Net::HTTP::Delete
}[method.upcase]
fail_with("Unsupported method: #{method}") unless request_class

request = request_class.new(uri)
request['Authorization'] = "Bearer #{token}"
request['Accept'] = 'application/json'

if body
  request['Content-Type'] = 'application/json'
  request.body = body
end

response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
  http.request(request)
end

parsed = begin
  JSON.parse(response.body) if response.body && !response.body.empty?
rescue JSON::ParserError
  response.body
end

case response
when Net::HTTPSuccess, Net::HTTPNoContent
  puts JSON.pretty_generate(parsed) unless parsed.nil?
else
  warn "#{response.code} #{response.message}"
  warn parsed.is_a?(String) ? parsed : JSON.pretty_generate(parsed)
  exit 1
end
