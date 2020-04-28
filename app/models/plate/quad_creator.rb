# frozen_string_literal: true

# require 'lib/nested_validators'
# The Quad creator takes 4 parent 96 well plates or size 96 tube-racks
# and transfers them onto a new 384 well plate
class Plate::QuadCreator
  include ActiveModel::Model

  attr_accessor :parents, :target_purpose, :user

  validate :all_parents_acceptable

  def save
    valid? && creation.save && transfer_request_collection.save
  end

  def target_plate
    @creation&.child
  end

  def self.target_coordinate_for(source_coordinate_name, quadrant_index)
    row_offset = quadrant_index % 2 # q0 -> 0, q1 -> 1, q2 -> 0, q3 -> 1
    col_offset = quadrant_index / 2 # q0 -> 0, q1 -> 0, q2 -> 1, q3 -> 1
    col, row = locn_coordinate(source_coordinate_name) # A1 -> 0, 0
    target_col = (col*2)+col_offset
    target_row = (row*2)+row_offset
    Map.location_from_row_and_column(target_row, target_col + 1) # this method expects target_col to be 1-indexed
  end

  def parent_barcodes=(quad_barcodes)
    @parent_barcodes = quad_barcodes
    found_parents = Labware.with_barcode(quad_barcodes.values)
    self.parents = quad_barcodes.transform_values do |barcode| 
      found_parents.detect { |candidate| candidate.any_barcode_matching?(barcode) } || :not_found
    end
  end

  def parent_barcodes
    @parent_barcodes ||= parents.transform_values { |parent| parent.machine_barcode }
  end

  private

  def all_parents_acceptable
    parents.each do |location, parent|
      case parent
      when Plate, TubeRack
        next if parent.size == 96
        add_error(location, 'is the wrong size')
      when :not_found
        add_error(location, 'could not be found')
      else
        add_error(location, 'is not a plate or tube rack')
      end
    end
  end

  def add_error(location, message)
    location_name = location.to_s.humanize
    errors.add(:parent_barcodes, "#{location_name} (#{parent_barcodes[location]}) #{message}")
  end

  def indexed_target_wells
    target_plate.wells.index_by(&:map_description)
  end

  def creation
    creationClass = PooledPlateCreation
    creationClass = PooledTubeRackCreation if parent_type == 'TubeRack'
    @creation ||= creationClass.new(user: user, parents: parents.values, child_purpose: target_purpose)
  end

  def transfer_request_collection
    @transfer_request_collection ||= TransferRequestCollection.new(
      user: user,
      transfer_requests_attributes: transfer_requests_attributes
    )
  end

  def transfer_requests_attributes
    # Logic for quad stamping.
    [:quad_1, :quad_2, :quad_3, :quad_4].each_with_index.flat_map do |quadrant_name, quadrant_index|
      next if parents[quadrant_name].blank?

      if parent_type == 'TubeRack'
        parents[quadrant_name].racked_tubes.map do |racked_tube|
          target_coordinate = Plate::QuadCreator.target_coordinate_for(racked_tube.coordinate, quadrant_index)
          {
            asset_id: racked_tube.tube.receptacle.id,
            target_asset_id: indexed_target_wells[target_coordinate].id
          }
        end
      else
        parents[quadrant_name].wells.map do |well|
          target_coordinate = Plate::QuadCreator.target_coordinate_for(well.map_description, quadrant_index)
          {
            asset_id: well.id,
            target_asset_id: indexed_target_wells[target_coordinate].id
          }
        end
      end
    end.compact
  end

  #
  # Converts a well or tube location name to its co-ordinates
  #
  # @param [<String>] Location name of the well or tube. Eg. A3
  #
  # @return [Array<Integer>] An array of two integers indicating column and row. eg. [0, 2]
  #
  def self.locn_coordinate(locn_name)
    [locn_name[1..-1].to_i - 1, locn_name.upcase.getbyte(0) - 'A'.getbyte(0)]
  end

  def parent_type
    @parent_type ||= parents.values.first.label
  end
end
