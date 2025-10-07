# frozen_string_literal: true

module Api
  module V1
    class SearchController < ApplicationController
      include ApiErrorHandler

      before_action :set_current_user_optional

      # GET /api/v1/search
      # Hybrid semantic + vector search with ACL filtering
      def index
        unless AzureSearch.configured?
          return render json: {
            error: {
              code: 'search_not_configured',
              message: 'Search functionality is not configured'
            }
          }, status: :service_unavailable
        end

        query_text = params[:q] || params[:query]
        if query_text.blank?
          return render json: {
            error: {
              code: 'missing_query',
              message: 'Query parameter "q" is required'
            }
          }, status: :bad_request
        end

        top = (params[:top] || 20).to_i.clamp(1, 100)
        skip = (params[:skip] || 0).to_i.clamp(0, 1000)
        note_id = params[:note_id]&.to_i
        enable_captions = params[:captions] != 'false' # Default true

        result = Search::Query.search(
          query_text: query_text,
          user: @current_user,
          top: top,
          skip: skip,
          note_id: note_id,
          enable_captions: enable_captions
        )

        render json: {
          results: result[:results],
          total_count: result[:total_count],
          query: query_text,
          top: top,
          skip: skip
        }, status: :ok
      rescue Search::Query::Error => e
        render json: {
          error: {
            code: 'search_error',
            message: e.message
          }
        }, status: :unprocessable_entity
      rescue => e
        Rails.logger.error("SearchController#index failed: #{e.class} - #{e.message}")
        render json: {
          error: {
            code: 'internal_error',
            message: 'An error occurred while searching'
          }
        }, status: :internal_server_error
      end

      # GET /api/v1/search/suggest
      # Autocomplete suggestions for search
      def suggest
        unless AzureSearch.configured?
          return render json: {
            error: {
              code: 'search_not_configured',
              message: 'Search functionality is not configured'
            }
          }, status: :service_unavailable
        end

        query_text = params[:q] || params[:query]
        if query_text.blank?
          return render json: { suggestions: [] }, status: :ok
        end

        top = (params[:top] || 5).to_i.clamp(1, 20)

        suggestions = Search::Query.suggest(
          query_text: query_text,
          user: @current_user,
          top: top
        )

        render json: { suggestions: suggestions }, status: :ok
      rescue Search::Query::Error => e
        render json: {
          error: {
            code: 'suggest_error',
            message: e.message
          }
        }, status: :unprocessable_entity
      rescue => e
        Rails.logger.error("SearchController#suggest failed: #{e.class} - #{e.message}")
        render json: {
          error: {
            code: 'internal_error',
            message: 'An error occurred while getting suggestions'
          }
        }, status: :internal_server_error
      end

      private

      # Set current_user if authenticated, but don't require authentication
      # This allows anonymous search of public content
      def set_current_user_optional
        @current_user = current_user if user_signed_in?
      end
    end
  end
end
