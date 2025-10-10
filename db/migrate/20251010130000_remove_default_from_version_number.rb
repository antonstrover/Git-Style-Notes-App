# frozen_string_literal: true

class RemoveDefaultFromVersionNumber < ActiveRecord::Migration[8.0]
  def up
    # Remove the default value from version_number column
    # The before_create callback will set the appropriate sequential value per note
    change_column_default :versions, :version_number, from: 1, to: nil
  end

  def down
    # Restore the default value if rolling back
    change_column_default :versions, :version_number, from: nil, to: 1
  end
end
