# frozen_string_literal: true

# Autogenerated migration to convert plate_creator_purposes to utf8mb4
class MigratePlateCreatorPurposesToUtf8mb4 < ActiveRecord::Migration[5.1]
  include MigrationExtensions::EncodingChanges

  def change
    change_encoding('plate_creator_purposes', from: 'latin1', to: 'utf8mb4')
  end
end
