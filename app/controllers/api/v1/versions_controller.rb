# frozen_string_literal: true

module Api
  module V1
    class VersionsController < ApplicationController
      include ApiErrorHandler

      before_action :authenticate_user!
      before_action :set_note
      before_action :set_version, only: [:show, :revert]

      # GET /api/v1/notes/:note_id/versions
      def index
        authorize @note, :show?

        @versions = @note.versions
                         .includes(:author)
                         .order(created_at: :desc)
                         .page(params[:page])
                         .per(params[:per_page] || 25)

        response.headers['X-Total-Count'] = @versions.total_count.to_s

        render json: @versions, status: :ok
      end

      # GET /api/v1/notes/:note_id/versions/:id
      def show
        authorize @version

        render json: @version.as_json(include: { author: { only: [:id, :email] } }), status: :ok
      end

      # POST /api/v1/notes/:note_id/versions
      def create
        authorize @note, :create_version?

        result = Versions::Create.call(
          note: @note,
          author: current_user,
          content: version_params[:content],
          summary: version_params[:summary],
          base_version_id: version_params[:base_version_id]
        )

        if result.success?
          Rails.logger.info "Version created: #{result.version.id} for note #{@note.id} by user #{current_user.id}"
          render json: result.version, status: :created
        else
          Rails.logger.warn "Version creation failed for note #{@note.id}: #{result.error}"
          render json: {
            error: {
              code: result.conflict? ? 'version_conflict' : 'validation_failed',
              message: result.error,
              details: result.errors
            }
          }, status: result.conflict? ? :conflict : :unprocessable_entity
        end
      end

      # POST /api/v1/notes/:note_id/versions/:id/revert
      def revert
        authorize @version, :revert?

        result = Versions::Revert.call(
          version: @version,
          author: current_user,
          summary: revert_params[:summary]
        )

        if result.success?
          Rails.logger.info "Version reverted: #{@version.id} for note #{@note.id} by user #{current_user.id}"
          render json: result.new_version, status: :created
        else
          render json: {
            error: {
              code: 'revert_failed',
              message: result.error,
              details: result.errors
            }
          }, status: :unprocessable_entity
        end
      end

      private

      def set_note
        @note = Note.find(params[:note_id])
      end

      def set_version
        @version = @note.versions.find(params[:id])
      end

      def version_params
        params.require(:version).permit(:content, :summary, :base_version_id)
      end

      def revert_params
        params.permit(:summary)
      end
    end
  end
end
