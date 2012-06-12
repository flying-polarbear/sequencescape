module ModelExtensions::Plate
  module NamedScopeHelpers
    def include_plate_named_scope(plate_association)
      named_scope :"include_#{plate_association}", {
        :include => { plate_association.to_sym => ::ModelExtensions::Plate::PLATE_INCLUDES }
      }
    end
  end

  PLATE_INCLUDES = [
    :plate_metadata, {
      :wells => [
        :map,
        :transfer_requests_as_target,
        :uuid_object, {
          :aliquots => [
            :bait_library, {
              :tag => :tag_group,
              :sample => [
                :uuid_object, {
                  :primary_study   => { :study_metadata => :reference_genome },
                  :sample_metadata => :reference_genome
                }
              ]
            }
          ]
        }
      ]
    }
  ]

  def self.included(base)
    base.class_eval do
      named_scope :include_plate_purpose, :include => :plate_purpose
      named_scope :include_plate_metadata, :include => :plate_metadata
      delegate :pool_id_for_well, :to => :plate_purpose, :allow_nil => true
    end
  end

  def plate_purpose_or_stock_plate
    self.plate_purpose || PlatePurpose.find_by_name('Stock Plate')
  end

  # Returns a hash from the submission for the pools to the wells that form that pool on this plate.  This is
  # not necessarily efficient but it is correct.  Unpooled wells, those without submissions, are completely
  # ignored within the returned result.
  def pools
    ActiveSupport::OrderedHash.new.tap do |pools|
      wells.walk_in_pools do |pool_id, wells|
        next if pool_id.blank?
        pool_information = { :wells => wells.map(&:map).map(&:description) }

        pools[pool_id] = pool_information
      end
    end
  end
end
