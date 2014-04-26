module DelayedJobView
  module Backend
    module Mongoid
      class << self
        def limited
          self # TODO: Implement me! See activerecord.rb
        end

        def all
          Delayed::Job.all
        end

        def failed
          Delayed::Job.where(:failed_at.ne => nil)
        end

        def active
          Delayed::Job.where(:failed_at => nil, :locked_by.ne => nil)
        end

        def queued
          Delayed::Job.where(failed_at: nil, locked_by: nil)
        end

        def destroy(id)
          dj = Delayed::Job.find(id)
          dj.destroy if dj
        end

        def retry(id)
          dj = Delayed::Job.find(id)
          dj.update_attribute :failed_at, nil if dj
        end
      end
    end
  end
end
