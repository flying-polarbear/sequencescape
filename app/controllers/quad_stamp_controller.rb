

class QuadStampController < ApplicationController
  before_action :set_plate_purposes, only: [:new, :create]
  before_action :set_barcode_printers, only: [:new, :create]

  # TODO: validation that at least one quadrant is filled
  # TODO: validation that all sources are sane type (plate OR tube rack

  def new
    @quad_creator = Plate::QuadCreator.new

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  def create
    @user = User.find_with_barcode_or_swipecard_code(params[:quad_creator][:user_barcode])
    @target_purpose = Purpose.find(params[:quad_creator][:target_purpose_id])
    @quad_creator = Plate::QuadCreator.new(parent_barcodes: parent_barcodes, target_purpose: @target_purpose, user: @user)

    if @quad_creator.save
      print_labels
      redirect_to asset_path(@quad_creator.target_plate), notice: "A new #{@target_purpose.name} plate was created and labels printed"
    else
      render :new
    end
  end

  private

  def print_labels
    print_job = LabelPrinter::PrintJob.new(params.dig(:barcode_printer, :name),
                                           LabelPrinter::Label::AssetRedirect,
                                           printables: @quad_creator.target_plate)
    if print_job.execute
      flash[:notice] = print_job.success
    else
      flash[:error] = print_job.errors.full_messages.join('; ')
    end
  end


  # Selects the appropriate plate purposes for the user to choose from.
  # In this case they must be 384-well stock plates.
  def set_plate_purposes
    @plate_purposes = Purpose.order(:name).where(size: 384, stock_plate: true).order('name asc')
  end

  # Selects barcode printers for the user to choose from.
  # Attempts to first get 384-well label specific printers (384-well plates take narrow 6mm labels)
  def set_barcode_printers
    @barcode_printers = BarcodePrinter.where(barcode_printer_type_id: BarcodePrinterType384DoublePlate.all).order('name asc')
    @barcode_printers = BarcodePrinter.where(barcode_printer_type_id: BarcodePrinterType96Plate.all).order('name asc') if @barcode_printers.blank?
  end

  def parent_barcodes
    params.require(:quad_creator)
          .require(:parent_barcodes)
          .reject { |key, barcode| barcode.blank? }
  end
end
