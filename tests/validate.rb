#!/usr/bin/env ruby
# frozen_string_literal: true

# Repository self-checks: run with `ruby tests/validate.rb` from repo root.
# Stdlib only (uses YAML frontmatter parsed by hand to avoid a gem dependency).

require 'json'
require 'pathname'

ROOT = Pathname.new(__dir__).parent
errors = []

def frontmatter(path)
  text = path.read
  return nil unless text.start_with?("---\n")

  _, fm, = text.split(/^---\s*$/, 3)
  fm
end

# 1. SKILL.md exists with required frontmatter fields
skill_md = ROOT.join('skills/timemagic/SKILL.md')
if skill_md.exist?
  fm = frontmatter(skill_md)
  if fm.nil?
    errors << 'SKILL.md missing YAML frontmatter block'
  else
    %w[name description license].each do |field|
      errors << "SKILL.md frontmatter missing `#{field}`" unless fm =~ /^#{field}:/
    end
    if fm =~ /^description:\s*(.+)$/
      desc = Regexp.last_match(1)
      errors << "SKILL.md description looks too long (#{desc.length} chars)" if desc.length > 1536
    end
  end
else
  errors << 'skills/timemagic/SKILL.md does not exist'
end

# 2. Required reference files exist
%w[
  authentication.md projects.md tasks.md activities.md goals.md
  time-entries.md estimations-and-reports.md errors-and-limits.md
].each do |name|
  path = ROOT.join('skills/timemagic/references', name)
  errors << "missing reference file: #{name}" unless path.exist?
end

# 3. Plugin manifest is valid JSON and points at the real skill dir
plugin_json = ROOT.join('.claude-plugin/plugin.json')
if plugin_json.exist?
  begin
    data = JSON.parse(plugin_json.read)
    errors << 'plugin.json missing name' unless data['name']
    Array(data['skills']).each do |skill_path|
      errors << "plugin.json references missing path: #{skill_path}" unless ROOT.join(skill_path).directory?
    end
  rescue JSON::ParserError => e
    errors << "plugin.json is not valid JSON: #{e.message}"
  end
else
  errors << '.claude-plugin/plugin.json does not exist'
end

# 4. Marketplace manifest is valid JSON
marketplace_json = ROOT.join('.claude-plugin/marketplace.json')
if marketplace_json.exist?
  begin
    JSON.parse(marketplace_json.read)
  rescue JSON::ParserError => e
    errors << "marketplace.json is not valid JSON: #{e.message}"
  end
else
  errors << '.claude-plugin/marketplace.json does not exist'
end

# 5. Eval cases file is valid JSON with both positive and negative cases
eval_file = ROOT.join('evals/trigger-cases.json')
if eval_file.exist?
  begin
    data = JSON.parse(eval_file.read)
    errors << 'evals/trigger-cases.json missing positive cases' if Array(data['positive']).empty?
    errors << 'evals/trigger-cases.json missing negative cases' if Array(data['negative']).empty?
  rescue JSON::ParserError => e
    errors << "evals/trigger-cases.json is not valid JSON: #{e.message}"
  end
else
  errors << 'evals/trigger-cases.json does not exist'
end

# 6. No obvious secrets committed (API tokens, private keys, etc.)
secret_patterns = [
  /TIMEMAGIC_API_TOKEN\s*=\s*(?!["'$<]|your[-_]?token)[^\s$'"#<]{8,}/i, # a literal token value, not a placeholder
  /-----BEGIN [A-Z ]*PRIVATE KEY-----/,
  /AKIA[0-9A-Z]{16}/ # AWS access key id shape
]
ROOT.glob('**/*').each do |path|
  next unless path.file?
  next if path.to_s.include?('.git/')

  content = begin
    path.read
  rescue StandardError
    next
  end
  secret_patterns.each do |pattern|
    errors << "possible secret in #{path.relative_path_from(ROOT)}" if content =~ pattern
  end
end

# 7. Helper script is syntactically valid Ruby
script = ROOT.join('skills/timemagic/scripts/timemagic_request.rb')
if script.exist?
  system('ruby', '-c', script.to_s, out: File::NULL) || errors << 'timemagic_request.rb fails `ruby -c` syntax check'
else
  errors << 'skills/timemagic/scripts/timemagic_request.rb does not exist'
end

if errors.empty?
  puts 'All checks passed.'
  exit 0
else
  puts "#{errors.size} problem(s) found:"
  errors.each { |e| puts "  - #{e}" }
  exit 1
end
