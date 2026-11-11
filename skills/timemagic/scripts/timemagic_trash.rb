#!/usr/bin/env ruby
# frozen_string_literal: true

# TimeMagic Trash helper. Stdlib only. Wraps the *read* and *restore* calls; it deliberately has no
# "recreate" command - recreating a deleted task is the ordinary create_task flow (see
# references/trash.md).
#
# Usage:
#   ruby timemagic_trash.rb list [--type task|project|activity] [--project UUID] [--query TEXT] [--page N] [--per-page N]
#   ruby timemagic_trash.rb show TYPE UUID
#   ruby timemagic_trash.rb export UUID [--mcp]
#   ruby timemagic_trash.rb restore TYPE UUID --confirmed
#
# `restore` changes data and refuses to run without --confirmed: pass it only after the user
# explicitly asked to restore that item.
#
# Reads the token from TIMEMAGIC_API_TOKEN (never as an argument) and the host from TIMEMAGIC_HOST.

require 'net/http'
require 'uri'
require 'json'
require 'cgi'
require_relative 'timemagic_client'

# Pure request building, separated from I/O so it can be tested without a network.
module TimeMagicTrash
  TYPES = %w[task project activity].freeze
  UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
  USAGE = <<~TEXT
    Usage:
      timemagic_trash.rb list [--type TYPE] [--project UUID] [--query TEXT] [--page N] [--per-page N]
      timemagic_trash.rb show TYPE UUID
      timemagic_trash.rb export UUID [--mcp]
      timemagic_trash.rb restore TYPE UUID --confirmed
    TYPE is one of: #{TYPES.join(', ')}
  TEXT

  class UsageError < StandardError; end

  Request = Struct.new(:verb, :path, keyword_init: true)

  module_function

  def build_request(argv)
    command, *rest = argv
    raise UsageError, 'No command given' unless command

    case command
    when 'list' then list_request(rest)
    when 'show' then show_request(rest)
    when 'export' then export_request(rest)
    when 'restore' then restore_request(rest)
    else raise UsageError, "Unknown command: #{command} (there is deliberately no 'recreate' command)"
    end
  end

  def list_request(args)
    flags = parse_flags(args, value_flags: %w[--type --project --query --page --per-page])
    type = flags['--type']
    raise UsageError, "Unsupported type: #{type}" if type && !TYPES.include?(type)

    params = { 'type' => type, 'project_uuid' => flags['--project'], 'query' => flags['--query'],
               'page' => flags['--page'], 'per_page' => flags['--per-page'] }.compact
    query = params.empty? ? '' : "?#{params.map { |k, v| "#{k}=#{CGI.escape(v)}" }.join('&')}"

    Request.new(verb: 'GET', path: "/api/trash#{query}")
  end

  def show_request(args)
    type, uuid = identify(args)

    Request.new(verb: 'GET', path: "/api/trash/#{type}/#{uuid}")
  end

  def export_request(args)
    flags = parse_flags(args, boolean_flags: %w[--mcp])
    uuid = flags[:positional].first
    raise UsageError, 'export needs a task UUID' unless uuid&.match?(UUID)

    variant = flags['--mcp'] ? '?variant=mcp' : ''

    Request.new(verb: 'GET', path: "/api/trash/task/#{uuid}/export#{variant}")
  end

  def restore_request(args)
    flags = parse_flags(args, boolean_flags: %w[--confirmed])
    type, uuid = identify(flags[:positional])
    unless flags['--confirmed']
      raise UsageError, 'restore changes data: pass --confirmed only after the user explicitly asked to restore this item'
    end

    Request.new(verb: 'POST', path: "/api/trash/#{type}/#{uuid}/restore")
  end

  def identify(args)
    type, uuid = args
    raise UsageError, "Unsupported or missing type: #{type.inspect}" unless TYPES.include?(type)
    raise UsageError, "Invalid UUID: #{uuid.inspect}" unless uuid&.match?(UUID)

    [type, uuid]
  end

  def parse_flags(args, value_flags: [], boolean_flags: [])
    result = { positional: [] }
    queue = args.dup

    until queue.empty?
      arg = queue.shift
      if value_flags.include?(arg)
        result[arg] = queue.shift or raise UsageError, "#{arg} needs a value"
      elsif boolean_flags.include?(arg)
        result[arg] = true
      elsif arg.start_with?('--')
        raise UsageError, "Unknown option: #{arg}"
      else
        result[:positional] << arg
      end
    end

    result
  end
end

def run_request(request)
  token = ENV.fetch('TIMEMAGIC_API_TOKEN', '')
  abort 'TIMEMAGIC_API_TOKEN is not set. Export it first; never pass it as an argument.' if token.empty?

  uri = URI.join(ENV.fetch('TIMEMAGIC_HOST', 'https://time-app.purple-magic.com'), request.path)
  http_request = (request.verb == 'POST' ? Net::HTTP::Post : Net::HTTP::Get).new(uri)
  TimeMagicClient.apply_headers(http_request, token: token)
  http_request['Content-Type'] = 'application/json'

  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(http_request) }
  paging = response.each_header.to_h.select { |name, _| name.start_with?('x-') }
  warn "HTTP #{response.code} #{paging.map { |k, v| "#{k}=#{v}" }.join(' ')}".strip
  parsed = begin
    JSON.parse(response.body.to_s)
  rescue JSON::ParserError
    nil
  end
  if TimeMagicClient.update_required?(response.code, parsed)
    warn TimeMagicClient.update_message(parsed)
    exit 3
  end
  puts(parsed ? JSON.pretty_generate(parsed) : response.body)
  exit(response.is_a?(Net::HTTPSuccess) ? 0 : 1)
end

if $PROGRAM_NAME == __FILE__
  begin
    run_request(TimeMagicTrash.build_request(ARGV))
  rescue TimeMagicTrash::UsageError => e
    warn "#{e.message}\n\n#{TimeMagicTrash::USAGE}"
    exit 2
  end
end
