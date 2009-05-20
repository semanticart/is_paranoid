class Person < ActiveRecord::Base #:nodoc:
  validates_uniqueness_of :name
  has_many :androids, :foreign_key => :owner_id, :dependent => :destroy
end

class Android < ActiveRecord::Base #:nodoc:
  validates_uniqueness_of :name
  has_many :components, :dependent => :destroy
  has_one :sticker
  has_many :memories, :foreign_key => 'parent_id'

  is_paranoid

  # this code is to ensure that our destroy and restore methods
  # work without triggering before/after_update callbacks
  before_update :raise_hell
  def raise_hell
    raise "hell"
  end
end

class Component < ActiveRecord::Base #:nodoc:
  is_paranoid
  belongs_to :android, :dependent => :destroy
  has_many :sub_components, :dependent => :destroy
  NEW_NAME = 'Something Else!'

  after_destroy :change_name
  def change_name
    self.update_attribute(:name, NEW_NAME)
  end
end

class SubComponent < ActiveRecord::Base #:nodoc:
  is_paranoid
  belongs_to :component, :dependent => :destroy
end

class Memory < ActiveRecord::Base #:nodoc:
  is_paranoid
  belongs_to :android, :class_name => "Android", :foreign_key => "parent_id"
end

class Sticker < ActiveRecord::Base #:nodoc
  is_paranoid
  belongs_to :android
end

class AndroidWithScopedUniqueness < ActiveRecord::Base #:nodoc:
  set_table_name :androids
  validates_uniqueness_of :name, :scope => :deleted_at
  is_paranoid
end

class Ninja < ActiveRecord::Base #:nodoc:
  validates_uniqueness_of :name, :scope => :visible
  is_paranoid :field => [:visible, false, true]
  
  alias_method :vanish, :destroy
end

class Pirate < ActiveRecord::Base #:nodoc:
  is_paranoid :field => [:alive, false, true]
end

class DeadPirate < ActiveRecord::Base #:nodoc:
  set_table_name :pirates
  is_paranoid :field => [:alive, true, false]
end

class RandomPirate < ActiveRecord::Base #:nodoc:
  set_table_name :pirates

  def after_destroy
    raise 'after_destroy works'
  end
end

class UndestroyablePirate < ActiveRecord::Base #:nodoc:
  set_table_name :pirates
  is_paranoid :field => [:alive, false, true]

  def before_destroy
    false
  end
end