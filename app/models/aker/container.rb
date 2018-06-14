module Aker
  # Phisical container for the biomaterial
  class Container < ApplicationRecord
    STOCK_PLATE_PURPOSE = 'Stock Plate'.freeze

    has_many :samples, dependent: :destroy

    belongs_to :asset

    validates :barcode, presence: true, uniqueness: { scope: :address }

    before_save :connect_asset!

    validate :not_change_barcode
    validate :not_change_address

    def not_change_barcode
      errors.add(:barcode, 'Cannot modify barcode') if persisted? && barcode_changed?
    end

    def not_change_address
      errors.add(:address, 'Cannot modify address') if persisted? && barcode_changed?
    end

    def connect_asset!
      return asset if asset
      labware = find_or_create_asset_by_aker_barcode!
      assign_attributes(asset: address ? labware.wells.located_at(address_for_ss).first : labware)
    end

    def find_or_create_asset_by_aker_barcode!
      labware = Asset.find_from_barcode(barcode)
      unless labware
        labware = PlatePurpose.find_by(name: STOCK_PLATE_PURPOSE).create!
        labware.aker_barcode = barcode
        labware.save!
      end
      labware
    end

    def address_for_ss
      address.delete(':')
    end

    def as_json(_options = {})
      {
        barcode: barcode,
        address: address
      }.compact
    end
  end
end
