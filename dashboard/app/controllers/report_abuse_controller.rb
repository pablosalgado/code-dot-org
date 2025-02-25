require 'json'
require 'httparty'

class ZendeskError < StandardError
  attr_reader :error_details

  def initialize(code, error_details)
    @error_details = error_details
    super("Zendesk failed with response code: #{code}")
  end

  def to_honeybadger_context
    {
      details: JSON.parse(@error_details)
    }
  end
end

class ReportAbuseController < ApplicationController
  AGE_CUSTOM_FIELD_ID = 24_024_923

  # Projects that are created by users with project validator permissions are
  # blocked from abuse reports because they are created internally and we know
  # they are safe. This reduces spamming of the report abuse feature.
  def protected_project?
    return false if params[:channel_id].blank?
    owner_storage_id, _ = storage_decrypt_channel_id(params[:channel_id])
    owner_user_id = user_id_for_storage_id(owner_storage_id)
    return false unless owner_user_id
    project_owner = User.find(owner_user_id)
    project_owner.permission?(UserPermission::PROJECT_VALIDATOR)
  end

  def report_abuse
    unless protected_project?
      unless Rails.env.development? || Rails.env.test?
        subject = FeaturedProject.featured_channel_id?(params[:channel_id]) ?
          'Featured Project: Abuse Reported' :
          'Abuse Reported'
        response = HTTParty.post(
          'https://codeorg.zendesk.com/api/v2/tickets.json',
          headers: {"Content-Type" => "application/json", "Accept" => "application/json"},
          body: {
            ticket: {
              requester: {
                name: (params[:name] == '' ? params[:email] : params[:name]),
                email: params[:email]
              },
              subject: subject,
              comment: {
                body: [
                  "URL: #{params[:abuse_url]}",
                  "abuse type: #{params[:abuse_type]}",
                  "user detail:",
                  params[:abuse_detail]
                ].join("\n")
              },
              custom_fields: [{id: AGE_CUSTOM_FIELD_ID, value: params[:age]}],
              tags: (params[:abuse_type] == 'infringement' ? ['report_abuse', 'infringement'] : ['report_abuse'])
            }
          }.to_json,
          basic_auth: {username: 'dev@code.org/token', password: Dashboard::Application.config.zendesk_dev_token}
        )
        raise ZendeskError.new(response.code, response.body) unless response.success?
      end

      if params[:channel_id].present?
        channels_path = "/v3/channels/#{params[:channel_id]}/abuse"
        assets_path = "/v3/assets/#{params[:channel_id]}/"
        files_path = "/v3/files/#{params[:channel_id]}/"

        _, _, body = ChannelsApi.call(
          'REQUEST_METHOD' => 'POST',
          'PATH_INFO' => channels_path,
          'REQUEST_PATH' => channels_path,
          'HTTP_COOKIE' => request.env['HTTP_COOKIE'],
          'rack.input' => StringIO.new
        )

        abuse_score = JSON.parse(body[0])["abuse_score"]

        FilesApi.call(
          'REQUEST_METHOD' => 'PATCH',
          'PATH_INFO' => assets_path,
          'REQUEST_PATH' => assets_path,
          'QUERY_STRING' => "abuse_score=#{abuse_score}",
          'HTTP_COOKIE' => request.env['HTTP_COOKIE'],
          'rack.input' => StringIO.new
        )

        FilesApi.call(
          'REQUEST_METHOD' => 'PATCH',
          'PATH_INFO' => files_path,
          'REQUEST_PATH' => files_path,
          'QUERY_STRING' => "abuse_score=#{abuse_score}",
          'HTTP_COOKIE' => request.env['HTTP_COOKIE'],
          'rack.input' => StringIO.new
        )
      end
    end

    redirect_to "https://support.code.org"
  end

  def report_abuse_form
    @react_props = {
      name: current_user&.name,
      email: current_user&.email,
      age: current_user&.age,
    }
  end
end
