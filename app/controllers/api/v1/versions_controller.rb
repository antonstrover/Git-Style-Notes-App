# frozen_string_literal: true

module Api
  module V1
    class VersionsController < ApplicationController
      include ApiErrorHandler

      before_action :authenticate_user!
      before_action :set_note
      before_action :set_version, only: [:show, :revert, :diff, :merge_preview, :revert_preview]

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

      # GET /api/v1/notes/:note_id/versions/:id/diff?compare_to=:other_version_id&mode=line|word&context=3
      def diff
        authorize @version, :diff?

        # Validate compare_to parameter
        compare_to_id = params[:compare_to]
        if compare_to_id.blank?
          return render json: {
            error: {
              code: 'missing_parameter',
              message: 'compare_to parameter is required'
            }
          }, status: :unprocessable_entity
        end

        if compare_to_id.to_i == @version.id
          return render json: {
            error: {
              code: 'invalid_parameter',
              message: 'compare_to cannot be the same as the current version'
            }
          }, status: :unprocessable_entity
        end

        # Find and authorize the comparison version
        compare_version = @note.versions.find_by(id: compare_to_id)
        unless compare_version
          return render json: {
            error: {
              code: 'not_found',
              message: 'Comparison version not found'
            }
          }, status: :not_found
        end

        authorize compare_version, :diff?

        # Build options
        options = {
          mode: params[:mode]&.to_sym || :line,
          context: (params[:context] || 3).to_i
        }

        # Validate mode
        unless [:line, :word].include?(options[:mode])
          return render json: {
            error: {
              code: 'invalid_parameter',
              message: 'mode must be either "line" or "word"'
            }
          }, status: :unprocessable_entity
        end

        # Compute diff with caching
        cache_key = "diff/#{@version.id}/#{compare_version.id}/#{options[:mode]}/#{options[:context]}"
        result = Rails.cache.fetch(cache_key, expires_in: Rails.application.config.diff_settings[:cache_ttl].seconds) do
          Diffs::Compute.new(
            left_content: @version.content,
            right_content: compare_version.content,
            options: options
          ).call
        end

        Rails.logger.info "Diff computed: version #{@version.id} vs #{compare_version.id}, mode=#{options[:mode]}"
        render json: {
          left_version: { id: @version.id, version_number: @version.version_number, summary: @version.summary },
          right_version: { id: compare_version.id, version_number: compare_version.version_number, summary: compare_version.summary },
          diff: result
        }, status: :ok
      rescue Diffs::Compute::ContentTooLargeError => e
        render json: {
          error: {
            code: 'content_too_large',
            message: e.message
          }
        }, status: :unprocessable_entity
      rescue Diffs::Compute::Error => e
        Rails.logger.error "Diff computation failed: #{e.message}"
        render json: {
          error: {
            code: 'diff_failed',
            message: e.message
          }
        }, status: :unprocessable_entity
      end

      # POST /api/v1/notes/:note_id/versions/:id/merge_preview
      # Body: { base_version_id, head_version_id }
      def merge_preview
        authorize @version, :merge_preview?

        base_version_id = params[:base_version_id]
        head_version_id = params[:head_version_id]

        if base_version_id.blank? || head_version_id.blank?
          return render json: {
            error: {
              code: 'missing_parameters',
              message: 'base_version_id and head_version_id are required'
            }
          }, status: :unprocessable_entity
        end

        # Find versions
        base_version = @note.versions.find_by(id: base_version_id)
        head_version = @note.versions.find_by(id: head_version_id)

        unless base_version && head_version
          return render json: {
            error: {
              code: 'not_found',
              message: 'Base or head version not found'
            }
          }, status: :not_found
        end

        # Compute three-way merge preview
        result = Diffs::MergePreview.new(
          base_content: base_version.content,
          local_content: @version.content,
          head_content: head_version.content
        ).call

        Rails.logger.info "Merge preview: base=#{base_version_id}, local=#{@version.id}, head=#{head_version_id}, status=#{result[:status]}"
        render json: {
          local_version: { id: @version.id, version_number: @version.version_number, summary: @version.summary },
          base_version: { id: base_version.id, version_number: base_version.version_number, summary: base_version.summary },
          head_version: { id: head_version.id, version_number: head_version.version_number, summary: head_version.summary },
          merge_preview: result
        }, status: :ok
      rescue Diffs::MergePreview::Error => e
        Rails.logger.error "Merge preview failed: #{e.message}"
        render json: {
          error: {
            code: 'merge_preview_failed',
            message: e.message
          }
        }, status: :unprocessable_entity
      end

      # GET /api/v1/notes/:note_id/versions/:id/revert_preview
      def revert_preview
        authorize @version, :diff?

        unless @note.head_version
          return render json: {
            error: {
              code: 'no_head_version',
              message: 'Note has no head version'
            }
          }, status: :unprocessable_entity
        end

        # Compute diff from this version to current head
        result = Diffs::Compute.new(
          left_content: @version.content,
          right_content: @note.head_version.content,
          options: { mode: :line, context: 3 }
        ).call

        Rails.logger.info "Revert preview: version #{@version.id} to head #{@note.head_version.id}"
        render json: {
          revert_from: { id: @version.id, version_number: @version.version_number, summary: @version.summary },
          current_head: { id: @note.head_version.id, version_number: @note.head_version.version_number, summary: @note.head_version.summary },
          diff: result
        }, status: :ok
      rescue Diffs::Compute::Error => e
        Rails.logger.error "Revert preview failed: #{e.message}"
        render json: {
          error: {
            code: 'revert_preview_failed',
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
