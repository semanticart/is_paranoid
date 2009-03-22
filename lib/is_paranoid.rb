require 'activerecord'

module IsParanoid
  def self.included(base) # :nodoc:
    base.extend SafetyNet
  end

  module SafetyNet
    # Call this in your model to enable all the safety-net goodness
    #
    #  Example:
    #
    #  class Android < ActiveRecord::Base
    #    is_paranoid
    #  end
    def is_paranoid
      class_eval do
        # This is the real magic.  All calls made to this model will append
        # the conditions deleted_at => nil.  Exceptions require using
        # exclusive_scope (see self.delete_all, self.count_with_destroyed,
        # and self.find_with_destroyed )
        default_scope :conditions => {:deleted_at => nil}

        # Actually delete the model, bypassing the safety net.  Because
        # this method is called internally by Model.delete(id) and on the
        # delete method in each instance, we don't need to specify those
        # methods separately
        def self.delete_all conditions = nil
          self.with_exclusive_scope do
            super conditions
          end
        end

        # Return a count that includes the soft-deleted models.
        def self.count_with_destroyed *args
          self.with_exclusive_scope { count(*args) }
        end

        # Return instances of all models matching the query regardless
        # of whether or not they have been soft-deleted.
        def self.find_with_destroyed *args
          self.with_exclusive_scope { find(*args) }
        end

        # Mark the model deleted_at as now.
        def destroy_without_callbacks
          self.update_attribute(:deleted_at, Time.now.utc)
        end

        # Override the default destroy to allow us to flag deleted_at.
        # This preserves the before_destroy and after_destroy callbacks.
        # Because this is also called internally by Model.destroy_all and
        # the Model.destroy(id), we don't need to specify those methods
        # separately.
        def destroy
          return false if callback(:before_destroy) == false
          result = destroy_without_callbacks
          callback(:after_destroy)
          result
        end

        # Set deleted_at flag on a model to nil, effectively undoing the
        # soft-deletion.
        def restore
          self.update_attribute(:deleted_at, nil)
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, IsParanoid)
