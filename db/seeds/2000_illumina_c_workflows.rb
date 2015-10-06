#This file is part of SEQUENCESCAPE is distributed under the terms of GNU General Public License version 1 or later;
#Please refer to the LICENSE and README files for information on licensing and authorship of this file.
#Copyright (C) 2013,2014,2015 Genome Research Ltd.
ActiveRecord::Base.transaction do
  IlluminaC::PlatePurposes.create_plate_purposes
  IlluminaC::PlatePurposes.create_tube_purposes
  IlluminaC::PlatePurposes.create_branches
  IlluminaC::Requests.create_request_types

  [
    {:name=>'General PCR',     :role=>'PCR',      :type=>'illumina_c_pcr'},
    {:name=>'General no PCR',  :role=>'No PCR',   :type=>'illumina_c_nopcr'},
    {:name=>'Multiplex',     :role=>'PCR',        :type=>'illumina_c_multiplexing',:skip_cherrypick => true}
  ].each do |options|
    IlluminaC::Helper::TemplateConstructor.new(options).build!
  end

end
