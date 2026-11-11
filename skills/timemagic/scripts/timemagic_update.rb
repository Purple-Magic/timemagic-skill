#!/usr/bin/env ruby
# frozen_string_literal: true

# Updates this skill in place from https://github.com/purple-magic/timemagic-skill. Stdlib + git.
#
# Usage: ruby timemagic_update.rb [--check]
#   --check   only report whether an update is available; change nothing
#
# - If the skill lives inside a git checkout of the repository: `git pull --ff-only`.
# - Otherwise (e.g. installed by `npx skills add`, which copies files): clone the repository into
#   a temporary directory and replace this skill's directory contents with skills/timemagic from it.
# Local changes are never overwritten in the git case (a non-fast-forward pull just fails).

require 'tmpdir'
require 'fileutils'
require 'open3'

module TimeMagicUpdate
  REPOSITORY = 'https://github.com/purple-magic/timemagic-skill'
  SKILL_DIR = File.expand_path('..', __dir__)

  module_function

  def git(*args, chdir:)
    out, status = Open3.capture2e('git', *args, chdir: chdir)
    [out.strip, status.success?]
  end

  def checkout_root
    out, ok = git('rev-parse', '--show-toplevel', chdir: SKILL_DIR)
    return unless ok

    remote, = git('remote', 'get-url', 'origin', chdir: out)
    out if remote.include?('purple-magic/timemagic-skill')
  end

  def read_version(root)
    File.read(File.join(root, 'VERSION')).strip
  rescue Errno::ENOENT
    'unknown'
  end

  def update_checkout(root, check_only:)
    before = read_version(root)
    if check_only
      _, ok = git('fetch', '--quiet', 'origin', chdir: root)
      return abort_with('Could not reach the repository.') unless ok

      behind, = git('rev-list', '--count', 'HEAD..@{u}', chdir: root)
      puts behind.to_i.positive? ? "Update available (installed #{before})." : "Up to date (#{before})."
      return
    end
    out, ok = git('pull', '--ff-only', chdir: root)
    return abort_with("Update failed:\n#{out}") unless ok

    puts "Updated #{before} -> #{read_version(root)}."
  end

  def update_copy(check_only:)
    Dir.mktmpdir('timemagic-skill-') do |tmp|
      _, ok = git('clone', '--depth', '1', '--quiet', REPOSITORY, tmp, chdir: Dir.pwd)
      return abort_with('Could not clone the repository.') unless ok

      latest = read_version(tmp)
      if check_only
        puts "Latest published skill version: #{latest} (this copy is not a git checkout, so it cannot compare)."
        return
      end
      FileUtils.cp_r(File.join(tmp, 'skills', 'timemagic', '.'), SKILL_DIR)
      puts "Updated skill files to #{latest}."
    end
  end

  def abort_with(message)
    warn message
    exit 1
  end

  def run(argv)
    check_only = argv.include?('--check')
    root = checkout_root
    root ? update_checkout(root, check_only: check_only) : update_copy(check_only: check_only)
  end
end

TimeMagicUpdate.run(ARGV) if $PROGRAM_NAME == __FILE__
