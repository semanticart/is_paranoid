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
    #
    # If you want to include ActiveRecord::Calculations to include your
    # destroyed models, do is_paranoid :with_calculations => true and you
    # will get sum_with_deleted, count_with_deleted, etc.
    def is_paranoid opts = {}
      opts[:field] ||= [:deleted_at, Proc.new{Time.now.utc}, nil]
      class_inheritable_accessor :destroyed_field, :field_destroyed, :field_not_destroyed
      self.destroyed_field, self.field_destroyed, self.field_not_destroyed = opts[:field]

      include Work
    end
  end

  module Work
    def self.included(base)
      base.class_eval do
        # This is the real magic.  All calls made to this model will append
        # the conditions deleted_at => nil.  Exceptions require using
        # exclusive_scope (see self.delete_all, self.count_with_destroyed,
        # and self.find_with_destroyed )
        default_scope :conditions => {destroyed_field => field_not_destroyed}

        # Actually delete the model, bypassing the safety net.  Because
        # this method is called internally by Model.delete(id) and on the
        # delete method in each instance, we don't need to specify those
        # methods separately
        def self.delete_all conditions = nil
          self.with_exclusive_scope { super conditions }
        end

        # Mark the model deleted_at as now.
        def destroy_without_callbacks
          self.update_attribute(destroyed_field, ( field_destroyed.respond_to?(:call) ? field_destroyed.call : field_destroyed))
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
          self.update_attribute(destroyed_field, field_not_destroyed)
        end

        # find_with_destroyed and other blah_with_destroyed and
        # blah_destroyed_only methods are defined here
        def self.method_missing name, *args
          if name.to_s =~ /^(.*)(_destroyed_only|_with_destroyed)$/ and self.respond_to?($1)
            self.extend(Module.new{
              if $2 == '_with_destroyed'                            # Example:
                define_method name do |*args|                       #  def count_with_destroyed(*args)
                  self.with_exclusive_scope{ self.send($1, *args) } #     self.with_exclusive_scope{ self.send(:count, *args) }
                end                                                 #  end
              else
                # Example:
                #  def count_destroyed_only(*args)
                #    self.with_exclusive_scope do
                #      with_scope({:find => { :conditions => ["#{destroyed_field} IS NOT ?", nil] }}) do
                #        self.send(:count, *args)
                #      end
                #    end
                #  end
                define_method name do |*args|
                  self.with_exclusive_scope do
                    with_scope({:find => { :conditions => ["#{self.table_name}.#{destroyed_field} IS NOT ?", field_not_destroyed] }}) do
                      self.send($1, *args)
                    end
                  end
                end
              end
            })
            self.send(name, *args)
          else
            super(name, *args)
          end
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, IsParanoid)
