# frozen_string_literal: true

class AddVersionNumberToVersions < ActiveRecord::Migration[8.0]
  def up
    # Add version_number column with NO default value - the before_create callback will set it
    # Start with null allowed for backfill
    add_column :versions, :version_number, :integer, null: true

    # Immediately drop any default that Rails/PostgreSQL may have added
    execute 'ALTER TABLE versions ALTER COLUMN version_number DROP DEFAULT'

    # Backfill version numbers for existing versions FIRST
    # For each note, order versions by created_at and assign sequential numbers
    say_with_time "Backfilling version numbers for existing versions" do
      Note.find_each do |note|
        note.versions.order(:created_at).each_with_index do |version, index|
          # Use update_column to bypass callbacks and validations
          version.update_column(:version_number, index + 1)
        end
      end
    end

    # Use raw SQL to set NOT NULL without adding a default
    # Rails' change_column_null may add a default value, so we use ALTER TABLE directly
    execute 'ALTER TABLE versions ALTER COLUMN version_number SET NOT NULL'

    # Add index AFTER backfilling to avoid duplicate key errors
    add_index :versions, [:note_id, :version_number], unique: true, name: 'index_versions_on_note_id_and_version_number'
  end

  def down
    remove_index :versions, name: 'index_versions_on_note_id_and_version_number'
    remove_column :versions, :version_number
  end
end
