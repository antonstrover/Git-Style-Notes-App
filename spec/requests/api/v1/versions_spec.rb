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
end
