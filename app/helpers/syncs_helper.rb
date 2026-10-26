module SyncsHelper
  def sync_progress_classes(sync)
    css_class = +"progress-bar"
    css_class << " bg-danger" if sync.errored?
    css_class << " bg-success" if sync.succeeded?
    css_class
  end
end
