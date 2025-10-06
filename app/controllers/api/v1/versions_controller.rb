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

        version = Versions::Create.new(
          note: @note,
          author: current_user,
          content: version_params[:content],
          summary: version_params[:summary],
          base_version_id: version_params[:base_version_id]
        ).call

        Rails.logger.info "Version created: #{version.id} for note #{@note.id} by user #{current_user.id}"
        render json: version, status: :created
      rescue Versions::Create::ConflictError => e
        Rails.logger.warn "Version conflict for note #{@note.id}: #{e.message}"
        render json: {
          error: {
            code: 'version_conflict',
            message: e.message,
            details: { head_version_id: @note.head_version_id }
          }
        }, status: :conflict
      rescue Versions::Create::Error => e
        Rails.logger.error "Version creation failed for note #{@note.id}: #{e.message}"
        render json: {
          error: {
            code: 'validation_failed',
            message: e.message
          }
        }, status: :unprocessable_entity
      end

      # POST /api/v1/notes/:note_id/versions/:id/revert
      def revert
        authorize @version, :revert?

        new_version = Versions::Revert.new(
          note: @note,
          author: current_user,
          target_version_id: @version.id,
          summary: revert_params[:summary]
        ).call

        Rails.logger.info "Version reverted: #{@version.id} for note #{@note.id} by user #{current_user.id}"
        render json: new_version, status: :created
      rescue Versions::Revert::Error => e
        Rails.logger.error "Version revert failed for note #{@note.id}: #{e.message}"
        render json: {
          error: {
            code: 'revert_failed',
            message: e.message
          }
        }, status: :unprocessable_entity
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
