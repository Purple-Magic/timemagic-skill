#!/usr/bin/env ruby
# frozen_string_literal: true

# Tests for scripts/timemagic_trash.rb request building (no network). Run: ruby tests/trash_script_test.rb
require 'minitest/autorun'
require_relative '../skills/timemagic/scripts/timemagic_trash'

class TrashScriptTest < Minitest::Test
  UUID = '6d0f5f3e-0b8a-4e57-9c0e-3a3c2d1e7a11'

  def build(*argv)
    TimeMagicTrash.build_request(argv)
  end

  def test_list_everything_is_a_read
    request = build('list')

    assert_equal %w[GET /api/trash], [request.verb, request.path]
  end

  def test_list_filters_are_escaped_and_sent_as_query_params
    request = build('list', '--type', 'task', '--project', UUID, '--query', 'q3 report & notes', '--page', '2')

    assert_equal 'GET', request.verb
    assert_equal "/api/trash?type=task&project_uuid=#{UUID}&query=q3+report+%26+notes&page=2", request.path
  end

  def test_list_rejects_unsupported_types
    assert_raises(TimeMagicTrash::UsageError) { build('list', '--type', 'user') }
    assert_raises(TimeMagicTrash::UsageError) { build('list', '--bogus') }
  end

  def test_show_reads_a_deleted_item
    assert_equal "/api/trash/task/#{UUID}", build('show', 'task', UUID).path
    assert_equal 'GET', build('show', 'project', UUID).verb
  end

  def test_show_validates_type_and_uuid
    assert_raises(TimeMagicTrash::UsageError) { build('show', 'task', '12') }
    assert_raises(TimeMagicTrash::UsageError) { build('show', 'task', "#{UUID}/../../users") }
    assert_raises(TimeMagicTrash::UsageError) { build('show', '../users', UUID) }
  end

  def test_export_is_a_read_and_mcp_is_a_variant
    assert_equal "/api/trash/task/#{UUID}/export", build('export', UUID).path
    assert_equal "/api/trash/task/#{UUID}/export?variant=mcp", build('export', UUID, '--mcp').path
    assert_equal 'GET', build('export', UUID).verb
  end

  def test_restore_requires_explicit_confirmation
    error = assert_raises(TimeMagicTrash::UsageError) { build('restore', 'task', UUID) }

    assert_match(/--confirmed/, error.message)
  end

  def test_confirmed_restore_is_the_only_write
    request = build('restore', 'task', UUID, '--confirmed')

    assert_equal ['POST', "/api/trash/task/#{UUID}/restore"], [request.verb, request.path]
  end

  def test_there_is_no_recreate_command
    error = assert_raises(TimeMagicTrash::UsageError) { build('recreate', UUID) }

    assert_match(/no 'recreate' command/, error.message)
    assert_raises(TimeMagicTrash::UsageError) { build }
  end
end
