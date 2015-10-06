#This file is part of SEQUENCESCAPE is distributed under the terms of GNU General Public License version 1 or later;
#Please refer to the LICENSE and README files for information on licensing and authorship of this file.
#Copyright (C) 2015 Genome Research Ltd.
class AddProductCataloguesToExistingTemplates < ActiveRecord::Migration

  class OrderRole < ActiveRecord::Base
    set_table_name('order_roles')
  end

  ORDER_ROLE_PRODUCT = {
    'PATH'    => 'PWGS',
    'ILB PATH'    => 'PWGS',
    'HWGS'    => 'MWGS',
    'ILB HWGS'    => 'MWGS',
    'ILA ISC' => 'ISC',
    'ILA WGS' => 'MWGS',
    'HSqX'    => 'HSqX',
    'ReISC'   => 'ReISC',
    'PWGS'    => 'PWGS',
    'MWGS'    => 'MWGS',
    'ISC'     => 'ISC'
  }

  def self.product_by_role(template)
    role_id = (template.submission_parameters||{})[:order_role_id]
    return nil if role_id.nil?
    product_name = ORDER_ROLE_PRODUCT[OrderRole.find(role_id).role]
    return nil if product_name.nil?
    Product.find_by_name!(product_name)
  end

  def self.product_by_name(template)
    product = case template.name
    when /Illumina-B.*WGS/ then 'PWGS'
    when /Illumina-B.*Multiplexed library creation/ then 'PWGS'
    when /Illumina-A - Pooled/                      then 'MWGS'
    when /Illumina-B - Pooled PATH/                 then 'PWGS'
    when /Pulldown Multiplex Library Preparation/   then 'ISC'
    when /ISC/                             then 'ISC'
    when / SC /                            then 'SC'
    when /Pulldown.*WGS/                   then 'MWGS'
    when /Illumina-A.*WGS/                 then 'MWGS'
    when /PacBio/                          then 'PacBio'
    when /Fluidigm/                        then 'Fluidigm'
    when /Illumina-C.*General PCR/         then 'GenericPCR'
    when /Illumina-C.*General no PCR/      then 'GenericNoPCR'
    when /Illumina-C.*Multiplexed Library/ then 'ClassicMultiplexed'
    when /TagQC/                           then 'InternalQC'
    when 'Cherrypick'                      then 'Manual'
    else 'Generic'
    end
  end

  def self.up
    ActiveRecord::Base.transaction do
      SubmissionTemplate.find_each do |template|
        say "Processing #{template.name}..."
        product = product_by_role(template)
        product ||= product_by_name(template)
        say "Setting to #{product}"
        template.product_catalogue = ProductCatalogue.find_by_name(product)
      end
    end
  end

  def self.down
    ActiveRecord::Base.transaction do
      SubmissionTemplate.update_all(:product_catalogue_id=>nil)
    end
  end
end
