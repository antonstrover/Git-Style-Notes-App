require 'rails_helper'

RSpec.describe 'Api::V1::Versions', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:note) { create(:note, :with_head_version, owner: user) }

  before { sign_in user }

  describe 'GET /api/v1/notes/:note_id/versions' do
    let!(:v1) { create(:version, note: note, created_at: 3.days.ago) }
    let!(:v2) { create(:version, note: note, created_at: 1.day.ago) }

    it 'returns 200 status' do
      get "/api/v1/notes/#{note.id}/versions"
      expect(response).to have_http_status(:ok)
    end

    it 'returns versions newest first' do
      get "/api/v1/notes/#{note.id}/versions"
      json = JSON.parse(response.body)

      expect(json.first['id']).to eq(v2.id)
      expect(json.last['id']).to eq(v1.id)
    end

    it 'includes X-Total-Count header' do
      get "/api/v1/notes/#{note.id}/versions"
      expect(response.headers['X-Total-Count']).to be_present
    end

    it 'paginates results' do
      create_list(:version, 30, note: note)

      get "/api/v1/notes/#{note.id}/versions", params: { per_page: 10 }
      json = JSON.parse(response.body)

      expect(json.length).to eq(10)
    end

    it 'requires permission to view note' do
      private_note = create(:note, owner: other_user, visibility: :private)

      get "/api/v1/notes/#{private_note.id}/versions"
      expect(response).to have_http_status(:forbidden)
    end

    it 'requires authentication' do
      sign_out user

      get "/api/v1/notes/#{note.id}/versions"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/notes/:note_id/versions/:id' do
    let(:version) { note.head_version }

    it 'returns 200 status' do
      get "/api/v1/notes/#{note.id}/versions/#{version.id}"
      expect(response).to have_http_status(:ok)
    end

    it 'returns version with author' do
      get "/api/v1/notes/#{note.id}/versions/#{version.id}"
      json = JSON.parse(response.body)

      expect(json['id']).to eq(version.id)
      expect(json['author']).to be_present
      expect(json['author']['id']).to eq(version.author.id)
    end

    it 'requires permission to view note' do
      private_note = create(:note, :with_head_version, owner: other_user, visibility: :private)

      get "/api/v1/notes/#{private_note.id}/versions/#{private_note.head_version.id}"
      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 404 for non-existent version' do
      get "/api/v1/notes/#{note.id}/versions/99999"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/notes/:note_id/versions' do
    let(:valid_params) do
      {
        version: {
          content: 'New version content',
          summary: 'Added new content'
        }
      }
    end

    it 'creates a new version' do
      # Mock the service call based on controller expectation
      result = double(success?: true, version: create(:version, note: note))
      allow(Versions::Create).to receive(:call).and_return(result)

      expect {
        post "/api/v1/notes/#{note.id}/versions", params: valid_params
      }.to change { Version.count }.by(1)
    end

    it 'returns 201 status' do
      result = double(success?: true, version: create(:version, note: note))
      allow(Versions::Create).to receive(:call).and_return(result)

      post "/api/v1/notes/#{note.id}/versions", params: valid_params
      expect(response).to have_http_status(:created)
    end

    it 'allows owner to create version' do
      result = double(success?: true, version: create(:version, note: note))
      allow(Versions::Create).to receive(:call).and_return(result)

      post "/api/v1/notes/#{note.id}/versions", params: valid_params
      expect(response).to have_http_status(:created)
    end

    it 'allows editor to create version' do
      editor = create(:user)
      create(:collaborator, :editor, note: note, user: editor)
      sign_in editor

      result = double(success?: true, version: create(:version, note: note))
      allow(Versions::Create).to receive(:call).and_return(result)

      post "/api/v1/notes/#{note.id}/versions", params: valid_params
      expect(response).to have_http_status(:created)
    end

    it 'denies viewer (403)' do
      viewer = create(:user)
      create(:collaborator, :viewer, note: note, user: viewer)
      sign_in viewer

      post "/api/v1/notes/#{note.id}/versions", params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    context 'with base_version_id (optimistic locking)' do
      let(:params_with_base) do
        {
          version: {
            content: 'Content',
            summary: 'Summary',
            base_version_id: note.head_version_id
          }
        }
      end

      it 'succeeds when base_version_id matches current head' do
        result = double(success?: true, version: create(:version, note: note))
        allow(Versions::Create).to receive(:call).and_return(result)

        post "/api/v1/notes/#{note.id}/versions", params: params_with_base
        expect(response).to have_http_status(:created)
      end

      it 'returns 409 conflict when base_version_id does not match' do
        result = double(success?: false, conflict?: true, error: 'Version conflict', errors: {})
        allow(Versions::Create).to receive(:call).and_return(result)

        post "/api/v1/notes/#{note.id}/versions", params: params_with_base
        expect(response).to have_http_status(:conflict)
      end

      it 'returns conflict error in standard format' do
        result = double(success?: false, conflict?: true, error: 'Version conflict', errors: {})
        allow(Versions::Create).to receive(:call).and_return(result)

        post "/api/v1/notes/#{note.id}/versions", params: params_with_base
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('version_conflict')
      end
    end

    context 'with validation errors' do
      it 'returns 422 status' do
        result = double(success?: false, conflict?: false, error: 'Validation failed', errors: {})
        allow(Versions::Create).to receive(:call).and_return(result)

        post "/api/v1/notes/#{note.id}/versions", params: valid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error in standard format' do
        result = double(success?: false, conflict?: false, error: 'Validation failed', errors: {})
        allow(Versions::Create).to receive(:call).and_return(result)

        post "/api/v1/notes/#{note.id}/versions", params: valid_params
        json = JSON.parse(response.body)

        expect(json['error']).to be_present
        expect(json['error']['code']).to eq('validation_failed')
      end
    end

    it 'logs version creation' do
      result = double(success?: true, version: create(:version, note: note))
      allow(Versions::Create).to receive(:call).and_return(result)
      allow(Rails.logger).to receive(:info)

      post "/api/v1/notes/#{note.id}/versions", params: valid_params

      expect(Rails.logger).to have_received(:info).with(/Version created/)
    end

    it 'logs failed creation' do
      result = double(success?: false, conflict?: false, error: 'Error', errors: {})
      allow(Versions::Create).to receive(:call).and_return(result)
      allow(Rails.logger).to receive(:warn)

      post "/api/v1/notes/#{note.id}/versions", params: valid_params

      expect(Rails.logger).to have_received(:warn).with(/Version creation failed/)
    end
  end

  describe 'POST /api/v1/notes/:note_id/versions/:id/revert' do
    let(:v1) { create(:version, note: note, content: 'Original') }
    let(:v2) { create(:version, note: note, content: 'Modified', parent_version: v1) }

    before do
      note.update_column(:head_version_id, v2.id)
    end

    it 'reverts to target version' do
      result = double(success?: true, new_version: create(:version, note: note, content: 'Original'))
      allow(Versions::Revert).to receive(:call).and_return(result)

      expect {
        post "/api/v1/notes/#{note.id}/versions/#{v1.id}/revert"
      }.to change { Version.count }.by(1)
    end

    it 'returns 201 status' do
      result = double(success?: true, new_version: create(:version, note: note))
      allow(Versions::Revert).to receive(:call).and_return(result)

      post "/api/v1/notes/#{note.id}/versions/#{v1.id}/revert"
      expect(response).to have_http_status(:created)
    end

    it 'allows owner to revert' do
      result = double(success?: true, new_version: create(:version, note: note))
      allow(Versions::Revert).to receive(:call).and_return(result)

      post "/api/v1/notes/#{note.id}/versions/#{v1.id}/revert"
      expect(response).to have_http_status(:created)
    end

    it 'allows editor to revert' do
      editor = create(:user)
      create(:collaborator, :editor, note: note, user: editor)
      sign_in editor

      result = double(success?: true, new_version: create(:version, note: note))
      allow(Versions::Revert).to receive(:call).and_return(result)

      post "/api/v1/notes/#{note.id}/versions/#{v1.id}/revert"
      expect(response).to have_http_status(:created)
    end

    it 'denies viewer (403)' do
      viewer = create(:user)
      create(:collaborator, :viewer, note: note, user: viewer)
      sign_in viewer

      post "/api/v1/notes/#{note.id}/versions/#{v1.id}/revert"
      expect(response).to have_http_status(:forbidden)
    end

    it 'accepts optional summary parameter' do
      result = double(success?: true, new_version: create(:version, note: note))
      expect(Versions::Revert).to receive(:call).with(
        hash_including(summary: 'Custom revert message')
      ).and_return(result)

      post "/api/v1/notes/#{note.id}/versions/#{v1.id}/revert",
           params: { summary: 'Custom revert message' }
    end

    context 'with errors' do
      it 'returns 422 status on failure' do
        result = double(success?: false, error: 'Revert failed', errors: {})
        allow(Versions::Revert).to receive(:call).and_return(result)

        post "/api/v1/notes/#{note.id}/versions/#{v1.id}/revert"
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error in standard format' do
        result = double(success?: false, error: 'Revert failed', errors: {})
        allow(Versions::Revert).to receive(:call).and_return(result)

        post "/api/v1/notes/#{note.id}/versions/#{v1.id}/revert"
        json = JSON.parse(response.body)

        expect(json['error']['code']).to eq('revert_failed')
      end
    end

    it 'logs successful revert' do
      result = double(success?: true, new_version: create(:version, note: note))
      allow(Versions::Revert).to receive(:call).and_return(result)
      allow(Rails.logger).to receive(:info)

      post "/api/v1/notes/#{note.id}/versions/#{v1.id}/revert"

      expect(Rails.logger).to have_received(:info).with(/Version reverted/)
    end
  end

  describe 'GET /api/v1/notes/:note_id/versions/:id/diff' do
    let(:v1) { create(:version, note: note, content: "Line 1\nLine 2\nLine 3\n") }
    let(:v2) { create(:version, note: note, content: "Line 1\nModified Line 2\nLine 3\n") }

    it 'returns diff between two versions' do
      get "/api/v1/notes/#{note.id}/versions/#{v1.id}/diff", params: { compare_to: v2.id }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['diff']).to be_present
      expect(json['diff']['hunks']).to be_an(Array)
      expect(json['diff']['stats']).to be_present
      expect(json['left_version']['id']).to eq(v1.id)
      expect(json['right_version']['id']).to eq(v2.id)
    end

    it 'requires compare_to parameter' do
      get "/api/v1/notes/#{note.id}/versions/#{v1.id}/diff"
      expect(response).to have_http_status(:unprocessable_entity)

      json = JSON.parse(response.body)
      expect(json['error']['code']).to eq('missing_parameter')
    end

    it 'rejects same version comparison' do
      get "/api/v1/notes/#{note.id}/versions/#{v1.id}/diff", params: { compare_to: v1.id }
      expect(response).to have_http_status(:unprocessable_entity)

      json = JSON.parse(response.body)
      expect(json['error']['code']).to eq('invalid_parameter')
    end

    it 'returns 404 for non-existent comparison version' do
      get "/api/v1/notes/#{note.id}/versions/#{v1.id}/diff", params: { compare_to: 99999 }
      expect(response).to have_http_status(:not_found)
    end

    it 'accepts mode parameter' do
      get "/api/v1/notes/#{note.id}/versions/#{v1.id}/diff",
          params: { compare_to: v2.id, mode: 'word' }
      expect(response).to have_http_status(:ok)
    end

    it 'rejects invalid mode parameter' do
      get "/api/v1/notes/#{note.id}/versions/#{v1.id}/diff",
          params: { compare_to: v2.id, mode: 'invalid' }
      expect(response).to have_http_status(:unprocessable_entity)

      json = JSON.parse(response.body)
      expect(json['error']['code']).to eq('invalid_parameter')
    end

    it 'accepts context parameter' do
      get "/api/v1/notes/#{note.id}/versions/#{v1.id}/diff",
          params: { compare_to: v2.id, context: 5 }
      expect(response).to have_http_status(:ok)
    end

    it 'allows any user who can view the note' do
      public_note = create(:note, :with_head_version, owner: other_user, visibility: :public)
      v_old = public_note.head_version
      v_new = create(:version, note: public_note, content: "New content\n")

      get "/api/v1/notes/#{public_note.id}/versions/#{v_old.id}/diff",
          params: { compare_to: v_new.id }
      expect(response).to have_http_status(:ok)
    end

    it 'denies access to private notes' do
      private_note = create(:note, :with_head_version, owner: other_user, visibility: :private)
      v_old = private_note.head_version
      v_new = create(:version, note: private_note, content: "New content\n")

      get "/api/v1/notes/#{private_note.id}/versions/#{v_old.id}/diff",
          params: { compare_to: v_new.id }
      expect(response).to have_http_status(:forbidden)
    end

    it 'uses caching for repeated requests' do
      # First request
      get "/api/v1/notes/#{note.id}/versions/#{v1.id}/diff", params: { compare_to: v2.id }
      expect(response).to have_http_status(:ok)

      # Second request should hit cache
      expect(Rails.cache).to receive(:fetch).and_call_original
      get "/api/v1/notes/#{note.id}/versions/#{v1.id}/diff", params: { compare_to: v2.id }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/v1/notes/:note_id/versions/:id/merge_preview' do
    let(:base) { create(:version, note: note, content: "Line 1\nLine 2\nLine 3\n") }
    let(:local) { create(:version, note: note, content: "Line 1\nLocal Change\nLine 3\n") }
    let(:head) { create(:version, note: note, content: "Line 1\nHead Change\nLine 3\n") }

    before do
      note.update_column(:head_version_id, head.id)
    end

    it 'returns merge preview' do
      post "/api/v1/notes/#{note.id}/versions/#{local.id}/merge_preview",
           params: { base_version_id: base.id, head_version_id: head.id }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['merge_preview']).to be_present
      expect(json['merge_preview']['status']).to be_in(['clean', 'conflicted'])
      expect(json['merge_preview']['hunks']).to be_an(Array)
      expect(json['merge_preview']['summary']).to be_present
      expect(json['local_version']['id']).to eq(local.id)
      expect(json['base_version']['id']).to eq(base.id)
      expect(json['head_version']['id']).to eq(head.id)
    end

    it 'requires base_version_id and head_version_id' do
      post "/api/v1/notes/#{note.id}/versions/#{local.id}/merge_preview"
      expect(response).to have_http_status(:unprocessable_entity)

      json = JSON.parse(response.body)
      expect(json['error']['code']).to eq('missing_parameters')
    end

    it 'returns 404 for non-existent versions' do
      post "/api/v1/notes/#{note.id}/versions/#{local.id}/merge_preview",
           params: { base_version_id: 99999, head_version_id: head.id }
      expect(response).to have_http_status(:not_found)
    end

    it 'requires edit permissions (denies viewers)' do
      viewer = create(:user)
      create(:collaborator, :viewer, note: note, user: viewer)
      sign_in viewer

      post "/api/v1/notes/#{note.id}/versions/#{local.id}/merge_preview",
           params: { base_version_id: base.id, head_version_id: head.id }
      expect(response).to have_http_status(:forbidden)
    end

    it 'allows editors' do
      editor = create(:user)
      create(:collaborator, :editor, note: note, user: editor)
      sign_in editor

      post "/api/v1/notes/#{note.id}/versions/#{local.id}/merge_preview",
           params: { base_version_id: base.id, head_version_id: head.id }
      expect(response).to have_http_status(:ok)
    end

    it 'detects clean merge' do
      clean_base = create(:version, note: note, content: "A\nB\nC\n")
      clean_local = create(:version, note: note, content: "A\nX\nC\n")
      clean_head = create(:version, note: note, content: "A\nB\nY\n")

      post "/api/v1/notes/#{note.id}/versions/#{clean_local.id}/merge_preview",
           params: { base_version_id: clean_base.id, head_version_id: clean_head.id }

      json = JSON.parse(response.body)
      expect(json['merge_preview']['status']).to eq('clean')
      expect(json['merge_preview']['summary']['conflict_count']).to eq(0)
    end

    it 'detects conflicts' do
      post "/api/v1/notes/#{note.id}/versions/#{local.id}/merge_preview",
           params: { base_version_id: base.id, head_version_id: head.id }

      json = JSON.parse(response.body)
      expect(json['merge_preview']['status']).to eq('conflicted')
      expect(json['merge_preview']['summary']['conflict_count']).to be > 0
    end
  end

  describe 'GET /api/v1/notes/:note_id/versions/:id/revert_preview' do
    let(:old_version) { create(:version, note: note, content: "Old Content\nLine 2\n") }
    let(:new_version) { create(:version, note: note, content: "New Content\nLine 2\n") }

    before do
      note.update_column(:head_version_id, new_version.id)
    end

    it 'returns diff preview for revert' do
      get "/api/v1/notes/#{note.id}/versions/#{old_version.id}/revert_preview"
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['diff']).to be_present
      expect(json['diff']['hunks']).to be_an(Array)
      expect(json['revert_from']['id']).to eq(old_version.id)
      expect(json['current_head']['id']).to eq(new_version.id)
    end

    it 'requires view permission' do
      private_note = create(:note, :with_head_version, owner: other_user, visibility: :private)
      old = private_note.head_version

      get "/api/v1/notes/#{private_note.id}/versions/#{old.id}/revert_preview"
      expect(response).to have_http_status(:forbidden)
    end

    it 'allows any user who can view the note' do
      public_note = create(:note, :with_head_version, owner: other_user, visibility: :public)
      old = public_note.head_version

      get "/api/v1/notes/#{public_note.id}/versions/#{old.id}/revert_preview"
      expect(response).to have_http_status(:ok)
    end

    it 'handles note without head version' do
      note_without_head = create(:note, owner: user, head_version: nil)
      version = create(:version, note: note_without_head)

      get "/api/v1/notes/#{note_without_head.id}/versions/#{version.id}/revert_preview"
      expect(response).to have_http_status(:unprocessable_entity)

      json = JSON.parse(response.body)
      expect(json['error']['code']).to eq('no_head_version')
    end

    it 'shows empty diff when reverting to current head' do
      get "/api/v1/notes/#{note.id}/versions/#{new_version.id}/revert_preview"
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      # Should have no changes since it's comparing version to itself
      expect(json['diff']['hunks']).to be_empty
    end
  end
end
