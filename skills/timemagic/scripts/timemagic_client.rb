# frozen_string_literal: true

# Shared by the skill's scripts: the API contract version this skill was written for, the headers
# every request carries, and the handling of the "skill update required" answer. Stdlib only.
module TimeMagicClient
  # The TimeMagic API contract version this copy of the skill speaks. Change it together with the
  # references/ when the API makes a breaking change (the app's ApiVersioning::SUPPORTED_API_VERSIONS).
  API_VERSION = '1'
  API_VERSION_HEADER = 'X-TimeMagic-API-Version'
  UPDATE_STATUS = 426
  UPDATE_CODE = 'skill_update_required'
  UPDATE_SCRIPT = File.expand_path('timemagic_update.rb', __dir__)

  module_function

  def apply_headers(request, token:)
    request['Authorization'] = "Bearer #{token}"
    request['Accept'] = 'application/json'
    request[API_VERSION_HEADER] = API_VERSION
    request
  end

  # True when the API says this skill is too old (or too new) for it.
  def update_required?(status, parsed_body)
    status.to_i == UPDATE_STATUS && parsed_body.is_a?(Hash) && parsed_body['code'] == UPDATE_CODE
  end

  def update_message(parsed_body)
    supported = Array(parsed_body['supported_api_versions']).join(', ')
    <<~TEXT
      TIMEMAGIC SKILL UPDATE REQUIRED
      This copy of the timemagic skill speaks API version #{API_VERSION}, but the TimeMagic API supports: #{supported}.
      Tell the user the skill is out of date and may behave incorrectly, then update it:
        ruby #{UPDATE_SCRIPT}
      (it updates from #{parsed_body['update_url']}). Retry the request after the update.
    TEXT
  end
end
