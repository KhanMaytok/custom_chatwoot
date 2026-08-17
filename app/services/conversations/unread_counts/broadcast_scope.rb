class Conversations::UnreadCounts::BroadcastScope
  attr_reader :event

  def initialize(event)
    @event = event
  end

  def perform
    return [conversation.account, conversation_users(conversation.account, current_and_previous_assignee_ids)] if conversation.present?

    deleted_conversation_scope
  end

  private

  def conversation
    event.data[:conversation]
  end

  def deleted_conversation_scope
    conversation_data = event.data[:conversation_data]&.with_indifferent_access
    return if conversation_data.blank?

    account = Account.find_by(id: conversation_data[:account_id])
    return if account.blank?

    [account, conversation_users(account, [conversation_data[:assignee_id]])]
  end

  def current_and_previous_assignee_ids
    ([conversation.assignee_id] + previous_assignee_ids).compact
  end

  def previous_assignee_ids
    changed_attributes = event.data[:changed_attributes]
    return [] unless changed_attributes.is_a?(Hash)

    assignee_change = changed_attributes.with_indifferent_access[:assignee_id]
    assignee_change.is_a?(Array) ? assignee_change.compact : []
  end

  def conversation_users(account, user_ids)
    account.users.where(id: user_ids.compact_blank.uniq)
  end
end
