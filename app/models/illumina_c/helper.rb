module IlluminaC::Helper

  require 'hiseq_2500_helper'

  ACCEPTABLE_REQUEST_TYPES = ['illumina_c_pcr','illumina_c_nopcr']
  ACCEPTABLE_SEQUENCING_REQUESTS = [
    'illumina_c_single_ended_sequencing',
    'illumina_c_paired_end_sequencing',
    'illumina_c_hiseq_paired_end_sequencing',
    'illumina_c_single_ended_hi_seq_sequencing',
    'illumina_c_miseq_sequencing',
    'illumina_c_hiseq_2500_paired_end_sequencing',
    'illumina_c_hiseq_2500_single_end_sequencing'
  ]
  PIPELINE = 'Illumina-C'
  class TemplateConstructor

    # Construct submission templates for the generic pipeline
    # opts is a hash
    # {
    #   :name => The Name for the Library Step
    #   :sequencing => Optional array of sequencing request type keys. Default is all.
    #   :role => The role that will be printed on barcodes
    #   :type => 'illumina_c_pcr'||'illumina_c_nopcr'
    # }
    attr_accessor :name, :type, :role
    attr_reader :sequencing

    def initialize(params)
      self.name = params[:name]
      self.type = params[:type]
      self.role = params[:role]
      self.sequencing = params[:sequencing]||ACCEPTABLE_SEQUENCING_REQUESTS
    end

    def sequencing=(sequencing_array)
      @sequencing = sequencing_array.map do |request|
        RequestType.find_by_key!(request)
      end
    end

    def validate!
      [:name,:type,:role].each do |value|
        raise "Must provide a #{value}" if send(value).nil?
      end
      raise "Request Type should be #{ACCEPTABLE_REQUEST_TYPES.join(', ')}" unless ACCEPTABLE_REQUEST_TYPES.include?(type)
      true
    end

    def name_for(cherrypick,sequencing_request_type)
      "#{PIPELINE} #{cherrypick ? "Cherrypicked - " : ''}#{name} - #{sequencing_request_type.name.gsub("#{PIPELINE} ",'')}"
    end

    def build!
      validate!
      each_submission_template do |config|
        SubmissionTemplate.create!(config)
      end
    end

    def cherrypick_id
      RequestType.find_by_key!()
    end

    def request_type_ids(cherrypick,sequencing)
      ids = cherrypick ? [[RequestType.find_by_key('cherrypick_for_illumina_c').id]] : []
      ids << [RequestType.find_by_key(type).id] << [sequencing.id]
    end

    def each_submission_template
      [true,false].each do |cherrypick|
        sequencing.each do |sequencing_request_type|
          yield({
            :name => name_for(cherrypick,sequencing_request_type),
            :submission_class_name => 'LinearSubmission',
            :submission_parameters => submission_parameters(cherrypick,sequencing_request_type),
            :product_line_id => ProductLine.find_by_name(PIPELINE),
          })
        end
      end
    end

    def submission_parameters(cherrypick,sequencing)
      sp = {
        :request_type_ids_list => request_type_ids(cherrypick,sequencing),
        :workflow_id => Submission::Workflow.find_by_key('short_read_sequencing').id,
        :order_role_id => Order::OrderRole.find_or_create_by_role(role).id,
        :info_differential => Submission::Workflow.find_by_key('short_read_sequencing').id
      }
      return sp if ['illumina_c_single_ended_sequencing','illumina_c_paired_end_sequencing'].include?(sequencing.key)
      sp.merge({
        :input_field_infos => Hiseq2500Helper.input_fields(sizes_for(sequencing),library_types)
      })
    end

    def sizes_for(sequencing)
      {
        'illumina_c_hiseq_2500_single_end_sequencing' => ["50"],
        'illumina_c_hiseq_2500_paired_end_sequencing' => ["75", "100"],
        'illumina_c_single_ended_hi_seq_sequencing' => ["50"],
        'illumina_c_hiseq_paired_end_sequencing' => ["50", "75", "100"],
        'illumina_c_miseq_sequencing' => ["25", "50", "130", "150", "250"]
      }[sequencing.key] || raise("No settings fo3 #{sequencing.key}")
    end

    def library_types
      ['ChIP Auto','RNAseq Manual','RNAseq Auto','FAIRE']
    end

    def self.find_for(name,sequencing=nil)
      tc = TemplateConstructor.new(:name=>name, :sequencing=>sequencing)
      [true,false].map do |cherrypick|
        tc.sequencing.map do |sequencing_request_type|
          SubmissionTemplate.find_by_name!(tc.name_for(cherrypick,sequencing_request_type))
        end
      end.flatten
    end

  end


end
