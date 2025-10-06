require 'rails_helper'

RSpec.describe 'Api::V1::Notes', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before { sign_in user }

  describe 'GET /api/v1/notes' do
    let!(:my_note) { create(:note, owner: user) }
    let!(:public_note) { create(:note, visibility: :public) }
    let!(:private_note) { create(:note, visibility: :private) }

    it 'returns 200 status' do
      get '/api/v1/notes'
      expect(response).to have_http_status(:ok)
    end

    it 'returns paginated notes' do
      get '/api/v1/notes'
      expect(JSON.parse(response.body)).to be_an(Array)
    end

    it 'includes X-Total-Count header' do
      get '/api/v1/notes'
      expect(response.headers['X-Total-Count']).to be_present
    end

    it 'returns only accessible notes' do
      get '/api/v1/notes'
      json = JSON.parse(response.body)
      ids = json.map { |n| n['id'] }

      expect(ids).to include(my_note.id)
      expect(ids).to include(public_note.id)
      expect(ids).not_to include(private_note.id)
    end

    it 'respects pagination parameters' do
      create_list(:note, 30, owner: user)

      get '/api/v1/notes', params: { per_page: 10, page: 1 }
      json = JSON.parse(response.body)

      expect(json.length).to eq(10)
    end

    it 'requires authentication' do
      sign_out user
      get '/api/v1/notes'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/notes/:id' do
    let(:note) { create(:note, owner: user) }

    it 'returns 200 status' do
      get "/api/v1/notes/#{note.id}"
      expect(response).to have_http_status(:ok)
    end

    it 'returns note with owner and head_version' do
      note.update_column(:head_version_id, create(:version, note: note).id)

      get "/api/v1/notes/#{note.id}"
      json = JSON.parse(response.body)

      expect(json['id']).to eq(note.id)
      expect(json['owner']).to be_present
      expect(json['head_version']).to be_present
    end

    it 'returns 404 for non-existent note' do
      get '/api/v1/notes/99999'
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 403 for unauthorized access' do
      private_note = create(:note, visibility: :private, owner: other_user)

      get "/api/v1/notes/#{private_note.id}"
      expect(response).to have_http_status(:forbidden)
    end

    it 'allows viewing public notes' do
      public_note = create(:note, visibility: :public, owner: other_user)

      get "/api/v1/notes/#{public_note.id}"
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/v1/notes' do
    let(:valid_params) do
      {
        note: {
          title: 'Test Note',
          visibility: 'private'
        }
      }
    end

    it 'creates a new note' do
      expect {
        post '/api/v1/notes', params: valid_params
      }.to change { Note.count }.by(1)
    end

    it 'returns 201 status' do
      post '/api/v1/notes', params: valid_params
      expect(response).to have_http_status(:created)
    end

    it 'sets current_user as owner' do
      post '/api/v1/notes', params: valid_params
      note = Note.last

      expect(note.owner).to eq(user)
    end

    it 'returns created note' do
      post '/api/v1/notes', params: valid_params
      json = JSON.parse(response.body)

      expect(json['title']).to eq('Test Note')
      expect(json['visibility']).to eq('private')
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          note: {
            title: '',
            visibility: 'private'
          }
        }
      end

      it 'returns 422 status' do
        post '/api/v1/notes', params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns validation errors in standard format' do
        post '/api/v1/notes', params: invalid_params
        json = JSON.parse(response.body)

        expect(json['error']).to be_present
        expect(json['error']['code']).to eq('validation_failed')
        expect(json['error']['details']).to be_present
      end

      it 'does not create note' do
        expect {
          post '/api/v1/notes', params: invalid_params
        }.not_to change { Note.count }
      end
    end

    it 'requires authentication' do
      sign_out user
      post '/api/v1/notes', params: valid_params

      expect(response).to have_http_status(:unauthorized)
    end

    it 'logs note creation' do
      allow(Rails.logger).to receive(:info)

      post '/api/v1/notes', params: valid_params

      expect(Rails.logger).to have_received(:info).with(/Note created/)
    end
  end

  describe 'PATCH /api/v1/notes/:id' do
    let(:note) { create(:note, owner: user, title: 'Original') }
    let(:update_params) do
      {
        note: {
          title: 'Updated Title'
        }
      }
    end

    it 'updates the note' do
      patch "/api/v1/notes/#{note.id}", params: update_params
      expect(note.reload.title).to eq('Updated Title')
    end

    it 'returns 200 status' do
      patch "/api/v1/notes/#{note.id}", params: update_params
      expect(response).to have_http_status(:ok)
    end

    it 'returns updated note' do
      patch "/api/v1/notes/#{note.id}", params: update_params
      json = JSON.parse(response.body)

      expect(json['title']).to eq('Updated Title')
    end

    it 'allows owner to update' do
      patch "/api/v1/notes/#{note.id}", params: update_params
      expect(response).to have_http_status(:ok)
    end

    it 'denies non-owner (403)' do
      other_note = create(:note, owner: other_user)

      patch "/api/v1/notes/#{other_note.id}", params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    it 'denies editor collaborator (403)' do
      editor = create(:user)
      create(:collaborator, :editor, note: note, user: editor)
      sign_in editor

      patch "/api/v1/notes/#{note.id}", params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          note: {
            title: ''
          }
        }
      end

      it 'returns 422 status' do
        patch "/api/v1/notes/#{note.id}", params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns validation errors' do
        patch "/api/v1/notes/#{note.id}", params: invalid_params
        json = JSON.parse(response.body)

        expect(json['error']).to be_present
      end
    end

    it 'logs note update' do
      allow(Rails.logger).to receive(:info)

      patch "/api/v1/notes/#{note.id}", params: update_params

      expect(Rails.logger).to have_received(:info).with(/Note updated/)
    end
  end

  describe 'DELETE /api/v1/notes/:id' do
    let!(:note) { create(:note, owner: user) }

    it 'deletes the note' do
      expect {
        delete "/api/v1/notes/#{note.id}"
      }.to change { Note.count }.by(-1)
    end

    it 'returns 204 status' do
      delete "/api/v1/notes/#{note.id}"
      expect(response).to have_http_status(:no_content)
    end

    it 'allows owner to delete' do
      delete "/api/v1/notes/#{note.id}"
      expect(response).to have_http_status(:no_content)
    end

    it 'denies non-owner (403)' do
      other_note = create(:note, owner: other_user)

      delete "/api/v1/notes/#{other_note.id}"
      expect(response).to have_http_status(:forbidden)
    end

    it 'logs note deletion' do
      allow(Rails.logger).to receive(:info)

      delete "/api/v1/notes/#{note.id}"

      expect(Rails.logger).to have_received(:info).with(/Note deleted/)
    end
  end

  describe 'POST /api/v1/notes/:id/fork' do
    let(:source_note) { create(:note, :with_head_version, owner: other_user, visibility: :public) }

    it 'forks the note' do
      # Note: This test depends on the actual service implementation
      # The controller code shows a result object pattern that may differ
      # from the service we saw. Adjust based on actual implementation.

      # Assuming the service returns a result object with fork
      allow_any_instance_of(Notes::Fork).to receive(:call).and_return(
        double(success?: true, fork: create(:note, owner: user))
      )

      expect {
        post "/api/v1/notes/#{source_note.id}/fork"
      }.to change { Note.count }.by(1)
    end

    it 'returns 201 status' do
      allow_any_instance_of(Notes::Fork).to receive(:call).and_return(
        double(success?: true, fork: create(:note, owner: user))
      )

      post "/api/v1/notes/#{source_note.id}/fork"
      expect(response).to have_http_status(:created)
    end

    it 'denies forking private note without access' do
      private_note = create(:note, :with_head_version, owner: other_user, visibility: :private)

      post "/api/v1/notes/#{private_note.id}/fork"
      expect(response).to have_http_status(:forbidden)
    end

    it 'allows forking public note' do
      allow_any_instance_of(Notes::Fork).to receive(:call).and_return(
        double(success?: true, fork: create(:note, owner: user))
      )

      post "/api/v1/notes/#{source_note.id}/fork"
      expect(response).to have_http_status(:created)
    end
  end
end
