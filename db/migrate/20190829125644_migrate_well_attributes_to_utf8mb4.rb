# frozen_string_literal: true

# Autogenerated migration to convert well_attributes to utf8mb4
class MigrateWellAttributesToUtf8mb4 < ActiveRecord::Migration[5.1]
  include MigrationExtensions::EncodingChanges

  def change
    change_encoding('well_attributes', from: 'latin1', to: 'utf8mb4')
  end
end
