#This file is part of SEQUENCESCAPE is distributed under the terms of GNU General Public License version 1 or later;
#Please refer to the LICENSE and README files for information on licensing and authorship of this file.
#Copyright (C) 2013 Genome Research Ltd.
class QcTube < MultiplexedLibraryTube
  delegate :qc_files, :qc_files=, :add_qc_file, :to => :parent
end
