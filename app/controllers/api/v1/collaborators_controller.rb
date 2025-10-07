# frozen_string_literal: true

module Api
  module V1
    class CollaboratorsController < ApplicationController
      include ApiErrorHandler

      before_action :authenticate_user!
      before_action :set_note

      # GET /api/v1/notes/:note_id/collaborators
      def index
        authorize @note, :show?

        @collaborators = @note.collaborators.includes(:user)

        render json: @collaborators.as_json(include: { user: { only: [:id, :email] } }), status: :ok
      end

      # POST /api/v1/notes/:note_id/collaborators
      def create
        authorize @note, :manage_collaborators?

        user = User.find(collaborator_params[:user_id])
        @collaborator = @note.collaborators.build(
          user: user,
          role: collaborator_params[:role] || 'editor'
        )

        if @collaborator.save
          Rails.logger.info "Collaborator added: user #{user.id} to note #{@note.id} by #{current_user.id}"

          # Reindex note to update ACL metadata
          if AzureSearch.configured?
            Search::ReindexNoteJob.perform_later(@note.id)
            Rails.logger.info "Enqueued Search::ReindexNoteJob for note #{@note.id} (collaborator added)"
          end

          render json: @collaborator.as_json(include: { user: { only: [:id, :email] } }), status: :created
        else
          render json: {
            error: {
              code: 'validation_failed',
              message: 'Validation failed',
              details: @collaborator.errors.as_json
            }
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/notes/:note_id/collaborators/:id
      def destroy
        authorize @note, :manage_collaborators?

        @collaborator = @note.collaborators.find(params[:id])
        @collaborator.destroy

        Rails.logger.info "Collaborator removed: #{@collaborator.id} from note #{@note.id} by #{current_user.id}"

        # Reindex note to update ACL metadata
        if AzureSearch.configured?
          Search::ReindexNoteJob.perform_later(@note.id)
          Rails.logger.info "Enqueued Search::ReindexNoteJob for note #{@note.id} (collaborator removed)"
        end

        head :no_content
      end

      private

      def set_note
        @note = Note.find(params[:note_id])
      end

      def collaborator_params
        params.require(:collaborator).permit(:user_id, :role)
      end
    end
  end
end
