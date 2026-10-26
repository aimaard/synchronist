class SyncsController < ApplicationController
  def index
    @syncs = Sync.ordered.limit(50)
  end

  def show
    @sync = Sync.find(params[:id])
    @sent_files = @sync.sent_files
    if params.key?(:filename)
      @sent_files = @sent_files.where("path LIKE ?", "%#{params[:filename]}%")
    end
  end
end
