# frozen_string_literal: true

module Api
  module V1
    class NotesController < ApplicationController
      include ApiErrorHandler

      before_action :authenticate_user!
      before_action :set_note, only: [:show, :update, :destroy, :fork]

      # GET /api/v1/notes
      def index
        @notes = policy_scope(Note)
                   .includes(:owner, :head_version)
                   .page(params[:page])
                   .per(params[:per_page] || 25)

        response.headers['X-Total-Count'] = @notes.total_count.to_s

        render json: @notes, status: :ok
      end

      # GET /api/v1/notes/:id
      def show
        authorize @note
        render json: @note.as_json(include: { owner: { only: [:id, :email] }, head_version: {} }), status: :ok
      end

      # POST /api/v1/notes
      def create
        @note = Note.new(note_params)
        @note.owner = current_user
        authorize @note

        if @note.save
          Rails.logger.info "Note created: #{@note.id} by user #{current_user.id}"
          render json: @note, status: :created
        else
          render json: {
            error: {
              code: 'validation_failed',
              message: 'Validation failed',
              details: @note.errors.as_json
            }
          }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/notes/:id
      def update
        authorize @note

        # Track if visibility changed to trigger reindexing
        visibility_changed = @note.will_save_change_to_visibility?

        if @note.update(note_params)
          Rails.logger.info "Note updated: #{@note.id} by user #{current_user.id}"

          # Reindex if visibility changed (ACL metadata needs update)
          if visibility_changed && AzureSearch.configured?
            Search::ReindexNoteJob.perform_later(@note.id)
            Rails.logger.info "Enqueued Search::ReindexNoteJob for note #{@note.id} (visibility changed)"
          end

          render json: @note, status: :ok
        else
          render json: {
            error: {
              code: 'validation_failed',
              message: 'Validation failed',
              details: @note.errors.as_json
            }
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/notes/:id
      def destroy
        authorize @note

        note_id = @note.id
        @note.destroy

        # Remove from search index
        if AzureSearch.configured?
          Search::DeleteByNoteJob.perform_later(note_id)
          Rails.logger.info "Enqueued Search::DeleteByNoteJob for note #{note_id}"
        end

        Rails.logger.info "Note deleted: #{note_id} by user #{current_user.id}"
        head :no_content
      end

      # POST /api/v1/notes/:id/fork
      def fork
        authorize @note, :fork?

        result = Notes::Fork.call(
          note: @note,
          user: current_user,
          title: params[:title]
        )

        if result.success?
          Rails.logger.info "Note forked: #{@note.id} -> #{result.fork.id} by user #{current_user.id}"
          render json: result.fork, status: :created
        else
          render json: {
            error: {
              code: 'fork_failed',
              message: result.error,
              details: result.errors
            }
          }, status: :unprocessable_entity
        end
      end

      private

      def set_note
        @note = Note.find(params[:id])
      end

      def note_params
        params.require(:note).permit(:title, :visibility)
      end
    end
  end
end
