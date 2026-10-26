class ReceivedFilesController < ApplicationController
  def index
    @received_files = ReceivedFile.ordered.limit(50)
    if params.key?(:filename)
      @received_files = @received_files.where("path LIKE ?", "%#{params[:filename]}%")
    end
  end
end
