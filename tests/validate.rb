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
  time-entries.md estimations-and-reports.md feature-requests.md errors-and-limits.md
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

# 8. AI Agent Context: the default ask-first workflows and the API contract stay documented
skill_text = skill_md.exist? ? skill_md.read : ''
workflows_text = ROOT.join('skills/timemagic/references/workflows.md').read
tasks_text = ROOT.join('skills/timemagic/references/tasks.md').read
tool_usage_text = ROOT.join('skills/timemagic/references/tool_usage.md').read

{
  'SKILL.md' => [skill_text, ['AI Agent Context on tasks', 'Creating a task: ask first', 'Editing a task: ask first',
                              'Never silently overwrite or erase', 'ai_context']],
  'references/workflows.md' => [workflows_text, ['## AI Agent Context', 'When you create a task: ask',
                                                 'When you edit a task: ask', 'When you work on a task: read it',
                                                 'Would you like to add AI Agent Context', 'batch-level',
                                                 'Never silently overwrite or erase existing context']],
  'references/tasks.md' => [tasks_text, ['`ai_context`', 'omitted key = preserved', '"ai_context": null']],
  'references/tool_usage.md' => [tool_usage_text, ['has_ai_context', 'ai_context']]
}.each do |file, (text, needles)|
  needles.each do |needle|
    errors << "#{file} must mention #{needle.inspect} (AI Agent Context workflow)" unless text.include?(needle)
  end
end

# Every JSON payload example in tasks.md must be valid JSON (```json blocks and `{"task": ...}` request lines)
tasks_text.scan(/```json\n(.*?)\n```/m).flatten.each do |block|
  JSON.parse(block.gsub('...', 'x'))
rescue JSON::ParserError => e
  errors << "references/tasks.md has an invalid ```json example: #{e.message[0, 80]}"
end
tasks_text.scan(/^\{"task": .*\}$/).each do |line|
  JSON.parse(line.gsub('...', 'x'))
rescue JSON::ParserError => e
  errors << "references/tasks.md has an invalid request body example: #{e.message[0, 80]}"
end

# The version is a plain three-number release and matches the plugin manifest
version = ROOT.join('VERSION').read.strip
errors << "VERSION #{version.inspect} is not a three-number version" unless version.match?(/\A\d+\.\d+\.\d+\z/)
if plugin_json.exist? && (manifest_version = JSON.parse(plugin_json.read)['version']) && manifest_version != version
  errors << "plugin.json version #{manifest_version} does not match VERSION #{version}"
end

if errors.empty?
  puts 'All checks passed.'
  exit 0
else
  puts "#{errors.size} problem(s) found:"
  errors.each { |e| puts "  - #{e}" }
  exit 1
end
