class CreateVersionedNotesSystem < ActiveRecord::Migration[7.0]
  def change
    # Notes table
    create_table :notes do |t|
      t.string :title, null: false, default: ''
      t.references :owner, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.bigint :head_version_id
      t.string :visibility, null: false, default: 'private'

      t.timestamps
    end

    add_index :notes, :visibility

    # Versions table
    create_table :versions do |t|
      t.references :note, null: false, foreign_key: { on_delete: :cascade }
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.bigint :parent_version_id
      t.string :summary, null: false, default: ''
      t.text :content, null: false

      t.timestamp :created_at, null: false
    end

    add_index :versions, [:note_id, :created_at]
    add_index :versions, :parent_version_id
    add_foreign_key :versions, :versions, column: :parent_version_id

    # Add foreign key from notes to versions (must be done after versions table exists)
    add_foreign_key :notes, :versions, column: :head_version_id
    add_index :notes, :head_version_id

    # Collaborators table
    create_table :collaborators do |t|
      t.references :note, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :role, null: false

      t.timestamps
    end

    add_index :collaborators, [:note_id, :user_id], unique: true

    # Forks table
    create_table :forks do |t|
      t.references :source_note, null: false, foreign_key: { to_table: :notes }
      t.references :target_note, null: false, foreign_key: { to_table: :notes }, index: { unique: true }

      t.timestamp :created_at, null: false
    end
  end
end
