
# frozen_string_literal: true

module Aker
  class Material < Aker::Mapping
    delegate :container, to: :sample

    def sample
      @instance
    end

    def attributes
      attrs = super
      attrs[:_id] = sample.name
      attrs
    end

    def model_for_table(table_name)
      return sample if table_name == :samples
      return sample.sample_metadata if table_name == :sample_metadata
      return sample.container.asset.well_attribute if table_name == :well_attribute
      nil
    end
  end
end