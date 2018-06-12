# TODO: Remove this class
module DelayedJobView
  module Backend
    BACKEND_METHODS = [:all, :failed, :active, :queued, :destroy, :retry, :limited].freeze

    class << self
      def used_backend
        @@used_backend ||= begin

          DelayedJobView::Backend::Mongoid
        rescue
          raise 'Delayed Job Viewer has no backend for Mongoid'
        end
      end

      BACKEND_METHODS << { to: :used_backend }
      # delegate *BACKEND_METHODS
    end
  end
end
