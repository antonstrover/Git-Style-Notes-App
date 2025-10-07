# frozen_string_literal: true

namespace :search do
  desc "Create or update Azure Search index"
  task setup: :environment do
    unless AzureSearch.configured?
      puts "❌ Azure Search not configured. Set required environment variables."
      exit 1
    end

    puts "🔧 Setting up Azure Search index: #{AzureSearch.index_name}"
    puts "   Service: #{AzureSearch.endpoint}"

    index_definition = build_index_definition

    begin
      response = HTTParty.put(
        "#{AzureSearch.endpoint}/indexes/#{AzureSearch.index_name}?api-version=#{AzureSearch.api_version}",
        headers: {
          "Content-Type" => "application/json",
          "api-key" => AzureSearch.api_key
        },
        body: index_definition.to_json,
        timeout: 30
      )

      if response.success?
        puts "✅ Index #{AzureSearch.index_name} created/updated successfully"
      else
        puts "❌ Failed to create/update index: #{response.code} #{response.message}"
        puts response.body
        exit 1
      end
    rescue => e
      puts "❌ Error: #{e.message}"
      exit 1
    end
  end

  desc "Delete Azure Search index"
  task delete: :environment do
    unless AzureSearch.configured?
      puts "❌ Azure Search not configured. Set required environment variables."
      exit 1
    end

    print "⚠️  Are you sure you want to delete index #{AzureSearch.index_name}? (yes/no): "
    confirmation = STDIN.gets.chomp
    unless confirmation.downcase == "yes"
      puts "Cancelled."
      exit 0
    end

    begin
      response = HTTParty.delete(
        "#{AzureSearch.endpoint}/indexes/#{AzureSearch.index_name}?api-version=#{AzureSearch.api_version}",
        headers: {
          "api-key" => AzureSearch.api_key
        },
        timeout: 30
      )

      if response.success? || response.code == 404
        puts "✅ Index #{AzureSearch.index_name} deleted"
      else
        puts "❌ Failed to delete index: #{response.code} #{response.message}"
        puts response.body
        exit 1
      end
    rescue => e
      puts "❌ Error: #{e.message}"
      exit 1
    end
  end

  desc "Reindex all notes"
  task reindex_all: :environment do
    unless AzureSearch.configured?
      puts "❌ Azure Search not configured. Set required environment variables."
      exit 1
    end

    total = Note.count
    puts "🔄 Reindexing #{total} notes..."

    Note.find_each.with_index do |note, index|
      Search::ReindexNoteJob.perform_later(note.id)
      print "\r   Enqueued: #{index + 1}/#{total}"
    end

    puts "\n✅ All notes enqueued for reindexing"
  end

  desc "Check Azure Search connection and index status"
  task status: :environment do
    unless AzureSearch.configured?
      puts "❌ Azure Search not configured. Set required environment variables."
      exit 1
    end

    puts "🔍 Azure Search Status"
    puts "   Service: #{AzureSearch.endpoint}"
    puts "   Index: #{AzureSearch.index_name}"
    puts ""

    begin
      # Check service
      response = HTTParty.get(
        "#{AzureSearch.endpoint}/indexes/#{AzureSearch.index_name}?api-version=#{AzureSearch.api_version}",
        headers: {
          "api-key" => AzureSearch.api_key
        },
        timeout: 10
      )

      if response.success?
        puts "✅ Index exists"
        index_data = JSON.parse(response.body)
        puts "   Fields: #{index_data['fields'].size}"
        puts "   Suggesters: #{index_data['suggesters']&.size || 0}"
        puts "   Semantic Configurations: #{index_data['semantic']&.dig('configurations')&.size || 0}"
      elsif response.code == 404
        puts "❌ Index does not exist. Run 'rake search:setup' to create it."
      else
        puts "❌ Error: #{response.code} #{response.message}"
      end

      # Check statistics
      stats_response = HTTParty.get(
        "#{AzureSearch.endpoint}/indexes/#{AzureSearch.index_name}/stats?api-version=#{AzureSearch.api_version}",
        headers: {
          "api-key" => AzureSearch.api_key
        },
        timeout: 10
      )

      if stats_response.success?
        stats = JSON.parse(stats_response.body)
        puts "   Document Count: #{stats['documentCount']}"
        puts "   Storage Size: #{stats['storageSize']} bytes"
      end
    rescue => e
      puts "❌ Error: #{e.message}"
      exit 1
    end
  end

  def build_index_definition
    {
      name: AzureSearch.index_name,
      fields: [
        { name: "id", type: "Edm.String", key: true, searchable: false, filterable: false, sortable: false },
        { name: "note_id", type: "Edm.Int64", searchable: false, filterable: true, sortable: true, facetable: true },
        { name: "version_id", type: "Edm.Int64", searchable: false, filterable: true, sortable: true },
        { name: "title", type: "Edm.String", searchable: true, filterable: false, sortable: false, analyzer: "standard.lucene" },
        { name: "content", type: "Edm.String", searchable: true, filterable: false, sortable: false, analyzer: "standard.lucene" },
        { name: "visibility", type: "Edm.String", searchable: false, filterable: true, sortable: false, facetable: true },
        { name: "owner_id", type: "Edm.Int64", searchable: false, filterable: true, sortable: false, facetable: true },
        { name: "allowed_user_ids", type: "Collection(Edm.Int64)", searchable: false, filterable: true },
        { name: "created_at", type: "Edm.DateTimeOffset", searchable: false, filterable: true, sortable: true },
        { name: "updated_at", type: "Edm.DateTimeOffset", searchable: false, filterable: true, sortable: true },
        {
          name: "title_vector",
          type: "Collection(Edm.Single)",
          searchable: true,
          dimensions: AzureSearch.embedding_dimensions,
          vectorSearchProfile: "vector-profile"
        },
        {
          name: "content_vector",
          type: "Collection(Edm.Single)",
          searchable: true,
          dimensions: AzureSearch.embedding_dimensions,
          vectorSearchProfile: "vector-profile"
        }
      ],
      vectorSearch: {
        algorithms: [
          {
            name: "vector-algorithm",
            kind: "hnsw",
            hnswParameters: {
              metric: "cosine",
              m: 4,
              efConstruction: 400,
              efSearch: 500
            }
          }
        ],
        profiles: [
          {
            name: "vector-profile",
            algorithm: "vector-algorithm"
          }
        ]
      },
      semantic: {
        configurations: [
          {
            name: "semantic-config",
            prioritizedFields: {
              titleField: {
                fieldName: "title"
              },
              contentFields: [
                { fieldName: "content" }
              ]
            }
          }
        ]
      },
      suggesters: [
        {
          name: "sg_notes_title",
          sourceFields: ["title"]
        }
      ]
    }
  end
end
