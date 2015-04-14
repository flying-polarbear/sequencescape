#This file is part of SEQUENCESCAPE is distributed under the terms of GNU General Public License version 1 or later;
#Please refer to the LICENSE and README files for information on licensing and authorship of this file.
#Copyright (C) 2012 Genome Research Ltd.
# Lays out the tags so that they are inverse column ordered.
module TagLayout::InInverseColumns
  extend self

  def direction
    'inverse column'
  end
end
