# frozen_string_literal: true

# Autogenerated migration to convert tag2_layouts to utf8mb4
class MigrateTag2LayoutsToUtf8mb4 < ActiveRecord::Migration[5.1]
  include MigrationExtensions::EncodingChanges

  def change
    change_encoding('tag2_layouts', from: 'utf8', to: 'utf8mb4')
  end
end
