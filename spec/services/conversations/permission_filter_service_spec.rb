require 'rails_helper'

RSpec.describe Conversations::PermissionFilterService do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:assigned_conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
  let!(:unassigned_conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:another_assigned_conversation) { create(:conversation, account: account, inbox: inbox, assignee: create(:user, account: account)) }

  # This inbox_member is used to establish the agent's access to the inbox
  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe '#perform' do
    context 'when user is an administrator' do
      it 'returns all conversations' do
        result = described_class.new(
          account.conversations,
          admin,
          account
        ).perform

        expect(result).to include(assigned_conversation)
        expect(result).to include(unassigned_conversation)
        expect(result).to include(another_assigned_conversation)
        expect(result.count).to eq(3)
      end
    end

    context 'when user is an agent' do
      it 'returns only conversations assigned to the agent' do
        result = described_class.new(
          account.conversations,
          agent,
          account
        ).perform

        expect(result).to include(assigned_conversation)
        expect(result).not_to include(unassigned_conversation)
        expect(result).not_to include(another_assigned_conversation)
        expect(result.count).to eq(1)
      end
    end
  end
end
