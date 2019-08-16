# frozen_string_literal: true

# Autogenerated migration to convert request_informations to utf8mb4
class MigrateRequestInformationsToUtf8mb4 < ActiveRecord::Migration[5.1]
  include MigrationExtensions::EncodingChanges

  def change
    change_encoding('request_informations', from: 'latin1', to: 'utf8mb4')
  end
end
