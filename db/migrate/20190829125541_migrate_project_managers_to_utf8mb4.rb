# frozen_string_literal: true

# Autogenerated migration to convert project_managers to utf8mb4
class MigrateProjectManagersToUtf8mb4 < ActiveRecord::Migration[5.1]
  include MigrationExtensions::EncodingChanges

  def change
    change_encoding('project_managers', from: 'latin1', to: 'utf8mb4')
  end
end
