class OrderPresenter
  ATTRIBUTES = [
    :study_id,
    :project_name,
    :plate_purpose_id,
    :sample_names_text,
    :lanes_of_sequencing_required,
    :comments,
  ]

  attr_accessor *ATTRIBUTES

  def initialize(order)
    @target_order = order
  end

  def method_missing(method, *args, &block)
    @target.send(method, *args, &block)
  end

end

class PresenterSkeleton
  class_inheritable_reader :attributes
  write_inheritable_attribute :attributes,  []

  def initialize(user, submission_attributes = {})
    submission_attributes = {} if submission_attributes.blank?

    @user = user

    attributes.each do |attribute|
      send("#{attribute}=", submission_attributes[attribute])
    end

    def id
      @id
    end

    def id=(submission_id)
      @id = submission_id
    end

  end

  def method_missing(name, *args, &block)
    name_without_assignment = name.to_s.sub(/=$/, '').to_sym
    return super unless attributes.include?(name_without_assignment)

    instance_variable_name = :"@#{name_without_assignment}"
    return instance_variable_get(instance_variable_name) if name_without_assignment == name.to_sym
    instance_variable_set(instance_variable_name, args.first)
  end
  protected :method_missing
end

class SubmissionCreater < PresenterSkeleton
  SubmissionsCreaterError  = Class.new(StandardError)
  IncorrectParamsException = Class.new(SubmissionsCreaterError)
  InvalidInputException    = Class.new(SubmissionsCreaterError)

  write_inheritable_attribute :attributes,  [
    :id,
    :template_id,
    :sample_names_text,
    :study_id,
    :submission_id,
    :project_name,
    :plate_purpose_id,
    :lanes_of_sequencing_required,
    :comments,
    :orders,
    :order_params,
    :asset_group_id
  ]


  def build_submission!
    begin
      submission.built!

    rescue ActiveRecord::RecordInvalid => exception
      exception.record.errors.full_messages.each do |message|
        submission.errors.add_to_base(message)
      end
    end
  end

  def find_asset_group
    AssetGroup.find(asset_group_id) if asset_group_id.present?
  end

  def order
    @order ||= template.new_order(
      :study           => study,
      :project         => project,
      :user            => @user,
      :request_options => order_params,
      :comments        => comments
    )

    if order_params
      @order.request_type_multiplier do |sequencing_request_type_id|
        @order.request_options['multiplier'][sequencing_request_type_id] = (lanes_of_sequencing_required || 1)
      end
    end

    @order
  end

  def order_params
    @order_params[:multiplier] = {} if (@order_params && @order_params[:multiplier].nil?)
    @order_params
  end

  # These fields should be defined by the submission template (to be renamed
  # order template) the old view code gets them by generating a new instance of
  # Order and then calling Order#input_field_infos.  This is a wrapper around
  # until I can refactor it out.
  def order_fields
    order.input_field_infos
  end

  # Return the submission's orders or a blank array
  def orders
    return [] unless submission.present?
    submission.try(:orders).map {|o| OrderPresenter.new(o) }
  end

  def project
    @project ||= Project.find_by_name(@project_name)
  end

  # Creates a new submission and adds an initial order on the submission using
  # the parameters
  def save
    begin
      ActiveRecord::Base.transaction do
        # Add assets to the order...
        order.update_attributes(order_assets)

        new_submission = order.create_submission(:user => order.user)
        new_submission.save!
        order.save!

        @submission = new_submission
      end

    rescue Quota::Error => quota_exception
      order.errors.add_to_base(quota_exception.message)
    rescue InvalidInputException => input_exception
      order.errors.add_to_base(input_exception.message)
    rescue IncorrectParamsException => exception
      order.errors.add_to_base(exception.message)
    rescue ActiveRecord::RecordInvalid => exception
      exception.record.errors.full_messages.each do |message|
        order.errors.add_to_base(message)
      end
    end

    # Having got through that lot, return whether the save was successful or not
    order.errors.empty?
  end

  def order_assets
    input_methods = [ :asset_group_id, :sample_names_text ].select { |input_method| send(input_method).present? }

    raise InvalidInputException, "No Samples found" if input_methods.empty?
    raise InvalidInputException, "Samples cannot be added from multiple sources at the same time." unless input_methods.size == 1


    return  case input_methods.first
            when :asset_group_id then { :asset_group => find_asset_group }
            when :sample_names_text then
              { :assets => wells_on_specified_plate_purpose_for(plate_purpose, find_samples_from_text(sample_names_text)) }

            else raise StandardError, "No way to determine assets for input choice #{input_choice.first}"
            end
  end

  # This is a legacy of the old controller...
  def wells_on_specified_plate_purpose_for(plate_purpose, samples)
    samples.map do |sample|
      sample.wells.all(:include => :plate).detect { |well| well.plate.present? and (well.plate.plate_purpose_id == plate_purpose.id) } or
        raise InvalidInputException, "No #{plate_purpose.name} plate found with sample: #{sample.name}"
    end
  end

  def plate_purpose
    @plate_purpose ||= PlatePurpose.find(plate_purpose_id)
  end

  # Returns Samples based on Sample name or Sanger ID
  # This is a legacy of the old controller...
  def find_samples_from_text(sample_text)
    names = sample_text.lines.map(&:chomp).reject(&:blank?).map(&:strip)

    samples = Sample.all(:include => :assets, :conditions => [ 'name IN (:names) OR sanger_sample_id IN (:names)', { :names => names } ])

    name_set  = Set.new(names)
    found_set = Set.new(samples.map { |s| [ s.name, s.sanger_sample_id ] }.flatten)
    not_found = name_set - found_set
    raise InvalidInputException, "#{Sample.table_name} #{not_found.to_a.join(", ")} not found" unless not_found.empty?
    return samples
  end
  private :find_samples_from_text

  def study
    @study ||= (Study.find(@study_id) if @study_id.present?)
  end

  def studies
    @studies ||= [ study ] if study.present?
    @studies ||= @user.interesting_studies.sort {|a,b| a.name <=> b.name }
  end

  def submission
    return nil unless id.present? || @submission
    @submission ||= Submission.find(id)
  end

  # Returns the SubmissionTemplate (OrderTemplate) to be used for this Submission.
  def template
    @template ||= SubmissionTemplate.find(@template_id)
  end

  def templates
    @templates ||= SubmissionTemplate.all
  end

  # Returns an array of all the names of studies associated with the current
  # user.
  def user_projects
    @user_projects ||= @user.sorted_project_names_and_ids.map(&:first)
  end
end


# TODO[sd9]: Refactor these presenters to a shared base class...
class SubmissionPresenter < PresenterSkeleton
  write_inheritable_attribute :attributes, [ :id ]

  def submission
    @submission ||= Submission.find(id)
  end

end



class SubmissionsController < ApplicationController

  def new
    @presenter = SubmissionCreater.new(current_user, :study_id => params[:study_id])
  end

  def create
    @presenter = SubmissionCreater.new(current_user, params[:submission])
    
    if @presenter.save
      @presenter.build_submission!
      render :partial => 'order_response', :layout => false
    else
      render :partial => 'order_errors', :layout => false
    end

  end

  def edit
    @presenter = SubmissionCreater.new(current_user,  :id => params[:id] )
  end

  # This method will build a submission then redirect to the submission on completion
  def update
    @presenter = SubmissionCreater.new(current_user, params[:submission])

    #@presenter.build_submission! temporarily disabled

    redirect_to @presenter.submission
  end
  
  def index
    @building = Submission.building.find(:all, :order => "created_at DESC", :conditions => { :user_id => current_user.id })
    @pending = Submission.pending.find(:all, :order => "created_at DESC", :conditions => { :user_id => current_user.id })
    @ready = Submission.ready.find(:all, :limit => 10, :order => "created_at DESC", :conditions => { :user_id => current_user.id })
  end

  def show
    @submission = Submission.find(params[:id])
    @presenter = SubmissionPresenter.new(current_user, params[:id])
  end
  
  def study
    @study = Study.find(params[:id])
    @submissions = @study.submissions
    
  end

  ###################################################               AJAX ROUTES
  # TODO[sd9]: These AJAX routes could be re-factored
  def order_fields
    @presenter = SubmissionCreater.new(current_user, params[:submission])

    render :partial => 'order_fields', :layout => false
  end

  def study_assets
    @presenter = SubmissionCreater.new(current_user, params[:submission])

    render :partial => 'study_assets', :layout => false
  end
  ##################################################         End of AJAX ROUTES
end

