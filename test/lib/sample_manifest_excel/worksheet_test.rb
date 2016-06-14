require_relative '../../test_helper'

class WorksheetTest < ActiveSupport::TestCase

	attr_reader :xls, :worksheet, :ranges, :plate_yaml, :conditional_formattings, :axlsx_worksheet, :sample_manifest, :column_list, :spreadsheet, :styles, :workbook, :ranges_worksheet, :range_list

	def setup
		@xls = Axlsx::Package.new
		@workbook = xls.workbook
		@ranges = YAML::load_file(File.expand_path(File.join(Rails.root,"test","data", "sample_manifest_excel","sample_manifest_validation_ranges.yml")))
    @conditional_formattings = YAML::load_file(File.expand_path(File.join(Rails.root,"test","data", "sample_manifest_excel","conditional_formatting.yml"))).with_indifferent_access
    @plate_yaml = YAML::load_file(File.expand_path(File.join(Rails.root,"test","data", "sample_manifest_excel","sample_manifest_columns_basic_plate.yml"))).with_indifferent_access
	  @sample_manifest = create(:sample_manifest_with_samples)
	  @column_list = SampleManifestExcel::ColumnList.new(plate_yaml, conditional_formattings)
	end

	context "base worksheet" do

		setup do
	    @range_list = build(:range_list, options: ranges)
	    @worksheet = SampleManifestExcel::Worksheet::Base.new workbook: workbook, columns: column_list, sample_manifest: sample_manifest, ranges: range_list, password: '1111', type: 'Plates'
	  	save_file
	  end

	  should "should have a axlsx worksheet" do
	  	assert worksheet.axlsx_worksheet
	  end

	end

	context "data worksheet" do

		setup do
			@range_list = build(:range_list, options: ranges)
	    @worksheet = SampleManifestExcel::Worksheet::DataWorksheet.new workbook: workbook, columns: column_list, sample_manifest: sample_manifest, ranges: range_list, password: '1111', type: 'Plates'
	  	save_file
	  end

		should "should have a axlsx worksheet" do
	  	assert worksheet.axlsx_worksheet
	  end

	  should "should add title and description" do
	    assert_equal "DNA Collections Form", spreadsheet.sheet(0).cell(1,1)
	    assert_equal "Study:", spreadsheet.sheet(0).cell(5,1)
	    assert_equal sample_manifest.study.abbreviation, spreadsheet.sheet(0).cell(5,2)
	    assert_equal "Supplier:", spreadsheet.sheet(0).cell(6,1)
	    assert_equal sample_manifest.supplier.name, spreadsheet.sheet(0).cell(6,2)
	    assert_equal "No. Plates Sent:", spreadsheet.sheet(0).cell(7,1)
    	assert_equal sample_manifest.count.to_s, spreadsheet.sheet(0).cell(7,2)
	  end

	  should "add standard headings to worksheet" do
	    worksheet.columns.headings.each_with_index do |heading, i|
	      assert_equal heading, spreadsheet.sheet(0).cell(9,i+1)
	    end
	  end

	  should "unlock cells for all columns which are unlocked" do
	  	worksheet.columns.values.select(&:unlocked?).each do |column|
	  		assert_equal worksheet.styles[:unlocked].reference, worksheet.axlsx_worksheet[column.range.first_cell.reference].style
	  		assert_equal worksheet.styles[:unlocked].reference, worksheet.axlsx_worksheet[column.range.last_cell.reference].style
	  	end
	  end

	  should "should add all of the samples" do
	    assert_equal sample_manifest.samples.count+9, spreadsheet.sheet(0).last_row
	  end

	  should "should add the attributes for each sample" do
	    [sample_manifest.samples.first, sample_manifest.samples.last].each do |sample|
	      worksheet.columns.each do |k, column|
	        assert_equal column.attribute_value(sample), spreadsheet.sheet(0).cell(sample_manifest.samples.index(sample)+10, column.number)
	      end
	    end
	  end

	  should "update all of the columns" do
	  	assert worksheet.columns.values.all? { |column| column.updated? }
	  end

	  should "panes should be frozen correctly" do
	    assert_equal worksheet.freeze_after_column(:sanger_sample_id), worksheet.axlsx_worksheet.sheet_view.pane.x_split
	    assert_equal worksheet.first_row-1, worksheet.axlsx_worksheet.sheet_view.pane.y_split
	    assert_equal "frozen", worksheet.axlsx_worksheet.sheet_view.pane.state
	  end

	  should "worksheet should be protected with password but columns and rows format can be changed" do
	    assert worksheet.axlsx_worksheet.sheet_protection.password
	    refute worksheet.axlsx_worksheet.sheet_protection.format_columns
	    refute worksheet.axlsx_worksheet.sheet_protection.format_rows
	  end

	end

	context "validations ranges worksheet" do

		attr_reader :range_worksheet

	  setup do
		  @range_list = build :range_list
	    @range_worksheet = SampleManifestExcel::Worksheet::RangesWorksheet.new(workbook: workbook, ranges: range_list)
	 	  save_file
	  end

	  should "should have a axlsx worksheet" do
	  	assert range_worksheet.axlsx_worksheet
	  end

	  should "add ranges to axlsx worksheet" do
	  	range = range_worksheet.ranges.first.last
	  	range.options.each_with_index do |option, i|
	  		assert_equal option, spreadsheet.sheet(0).cell(1,i+1)
	  	end
	  	assert_equal range_worksheet.ranges.count, spreadsheet.sheet(0).last_row
	  end

	  should "set absolute references in ranges" do
	  	range = range_list.ranges.values.first
    	assert_equal "Ranges!#{range.reference}", range.absolute_reference
    	assert range_list.all? {|k, range| range.absolute_reference.present?}
	  end

	end

	def teardown
    File.delete('test.xlsx') if File.exists?('test.xlsx')
  end

  def save_file
		@xls.serialize('test.xlsx')
	  @spreadsheet = Roo::Spreadsheet.open('test.xlsx')
  end

end