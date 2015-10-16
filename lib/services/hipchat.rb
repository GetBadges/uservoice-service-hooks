class Services::Hipchat < Services::Base
  service_name "HipChat"
  events_allowed %w[ new_ticket new_ticket_reply new_ticket_admin_reply new_suggestion new_comment new_kudo new_article new_forum new_user_story suggestion_status_update suggestion_votes_update ]
  string :auth_token, lambda { _("Auth token") }, lambda { _('See %{link}') % {:link => '<a href="https://www.hipchat.com/docs/api/auth">https://www.hipchat.com/docs/api/auth</a>'.html_safe} }
  string :room, lambda { _("Room Name") }, lambda { _('You can see a list of your rooms at %{link}') % {:link => '<a href="https://www.hipchat.com/rooms/ids">https://www.hipchat.com/rooms/ids</a>'.html_safe} }
  boolean :notify, lambda { _("Notify") }, lambda { _('Check this to notify everyone in the HipChat room whenever an event is triggered') }

  def perform
    return false if data['auth_token'].blank? || data['room'].blank?
    uri = URI.parse("https://api.hipchat.com/v1/rooms/message")
    request = Net::HTTP::Post.new(uri.path)
    request.set_form_data :auth_token => data['auth_token'],
                          :room_id => data['room'],
                          :from => 'UserVoice',
                          :message => message,
                          :notify => data['notify'] ? 1 : 0
    http = Net::HTTP.new(uri.host, 443)
    http.use_ssl = true
    response = http.request(request)
    return response.is_a?(Net::HTTPSuccess)
  end

  def message
    data = api_hash
    case event
    when 'new_kudo'
      "#{data['kudo']['message']['sender']['name']} received <b>Kudos</b>! from #{data['kudo']['sender']['name']} on <a href='#{data['kudo']['ticket']['url']}'>#{data['kudo']['ticket']['subject']}</a>"
    when 'new_ticket'
      "<b>New ticket</b> from #{data['ticket']['created_by']['name']}: <a href='#{data['ticket']['url']}'>#{data['ticket']['subject']}</a>"
    when 'new_ticket_reply', 'new_ticket_admin_reply'
      "<b>New ticket reply</b> from #{data['message']['sender']['name']} on <a href='#{data['ticket']['url']}'>#{data['ticket']['subject']}</a>"
    when 'new_suggestion'
      "<b>New idea</b> by #{data['suggestion']['creator']['name']}: <a href='#{data['suggestion']['url']}'>#{data['suggestion']['title']}</a>"
    when 'new_comment'
      "<b>New comment</b> by #{data['comment']['creator']['name']} on <a href='#{data['comment']['suggestion']['url']}'>#{data['comment']['suggestion']['title']}</a>"
    when 'new_article'
      "<b>New article</b> created by #{data['article']['updated_by']['name']}: <a href='#{data['article']['url']}'>#{data['article']['question']}</a>"
    when 'new_forum'
      "<b>New forum</b>: <a href='#{data['forum']['url']}'>#{data['forum']['name']}</a> created by #{data['forum']['updated_by']['name']}"
    when 'suggestion_status_update'
      "<b>New idea status update</b> by #{data['audit_status']['user']['name']} on <a href='#{data['audit_status']['suggestion']['url']}'>#{data['audit_status']['suggestion']['title']}</a>"
    when 'suggestion_votes_update'
      "<b>New idea votes update</b> on <a href='#{data['suggestion']['url']}'>#{data['suggestion']['title']}</a>: #{data['suggestion']['vote_count']} votes"
    when 'new_user_story'
      if data['user_story']['ticket']
        source = " via ticket ##{data['user_story']['ticket']['ticket_number']}: <a href='#{data['user_story']['ticket']['url']}'>#{data['user_story']['ticket']['subject']}</a>"
      elsif data['user_story']['source_url'].present?
        source = " via <a href='#{data['user_story']['source_url']}'>#{data['user_story']['source_url']}</a>"
      else
        source = ""
      end
      if data['user_story']['user']['email']
        user = "#{data['user_story']['user']['name']} <#{data['user_story']['user']['email']}>"
      else
        user = data['user_story']['user']['name']
      end
      "#{user} gave feedback about <a href='#{data['user_story']['suggestion']['url']}'>#{data['user_story']['suggestion']['title']}</a>#{source}"
    else
      super
    end
  end
end
