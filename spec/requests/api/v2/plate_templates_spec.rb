# frozen_string_literal: true

require 'rails_helper'

describe 'PlateTemplates API', with: :api_v2 do
  context 'with multiple PlateTemplates' do
    before do
      create_list(:plate_template, 5)
    end

    it 'sends a list of plate_templates' do
      api_get '/api/v2/plate_templates'
      # test for the 200 status-code
      expect(response).to have_http_status(:success)
      # check to make sure the right amount of messages are returned
      expect(json['data'].length).to eq(5)
    end

    # Check filters, ESPECIALLY if they aren't simple attribute filters
  end

  context 'with a PlateTemplate' do
    let(:resource_model) { create :plate_template }

    it 'sends an individual PlateTemplate' do
      api_get "/api/v2/plate_templates/#{resource_model.id}"
      expect(response).to have_http_status(:success)
      expect(json.dig('data', 'type')).to eq('plate_templates')
    end

    let(:payload) do
      {
        'data' => {
          'id' => resource_model.id,
          'type' => 'plate_templates',
          'attributes' => {
            # Set new attributes
          }
        }
      }
    end

    # Remove if immutable
    it 'allows update of a PlateTemplate' do
      api_patch "/api/v2/plate_templates/#{resource_model.id}", payload
      expect(response).to have_http_status(:success)
      expect(json.dig('data', 'type')).to eq('plate_templates')
      # Double check at least one of the attributes
      # eg. expect(json.dig('data', 'attributes', 'state')).to eq('started')
    end
  end
end
