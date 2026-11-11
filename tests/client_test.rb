#!/usr/bin/env ruby
# frozen_string_literal: true

# Tests for the shared client (no network). Run: ruby tests/client_test.rb
require 'minitest/autorun'
require 'net/http'
require_relative '../skills/timemagic/scripts/timemagic_client'

class ClientTest < Minitest::Test
  BODY = { 'code' => 'skill_update_required', 'supported_api_versions' => %w[2 3],
           'update_url' => 'https://github.com/purple-magic/timemagic-skill' }.freeze

  def test_requests_declare_the_api_version
    request = TimeMagicClient.apply_headers(Net::HTTP::Get.new('/api/projects'), token: 't')

    assert_equal TimeMagicClient::API_VERSION, request['X-TimeMagic-API-Version']
    assert_equal 'Bearer t', request['Authorization']
  end

  def test_recognises_the_update_required_answer
    assert TimeMagicClient.update_required?('426', BODY)
    refute TimeMagicClient.update_required?('401', BODY)
    refute TimeMagicClient.update_required?('426', { 'code' => 'other' })
    refute TimeMagicClient.update_required?('426', nil)
  end

  def test_message_tells_the_agent_to_update
    message = TimeMagicClient.update_message(BODY)

    assert_includes message, 'SKILL UPDATE REQUIRED'
    assert_includes message, 'timemagic_update.rb'
    assert_includes message, '2, 3'
  end
end
