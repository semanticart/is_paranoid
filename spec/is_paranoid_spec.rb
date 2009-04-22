require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class Person < ActiveRecord::Base
  validates_uniqueness_of :name
  has_many :androids, :foreign_key => :owner_id, :dependent => :destroy
end

class Android < ActiveRecord::Base
  validates_uniqueness_of :name

  is_paranoid

  before_update :raise_hell
  def raise_hell
    raise "hell"
  end
end

class AndroidWithScopedUniqueness < ActiveRecord::Base
  set_table_name :androids
  validates_uniqueness_of :name, :scope => :deleted_at
  is_paranoid
end

class NoCalculation < ActiveRecord::Base
  is_paranoid
end

class Ninja < ActiveRecord::Base
  validates_uniqueness_of :name, :scope => :visible
  is_paranoid :field => [:visible, false, true]
end

class Pirate < ActiveRecord::Base
  is_paranoid :field => [:alive, false, true]
end

class DeadPirate < ActiveRecord::Base
  set_table_name :pirates
  is_paranoid :field => [:alive, true, false]
end

describe Android do
  before(:each) do
    Android.delete_all
    Person.delete_all

    @luke = Person.create(:name => 'Luke Skywalker')
    @r2d2 = Android.create(:name => 'R2D2', :owner_id => @luke.id)
    @c3p0 = Android.create(:name => 'C3P0', :owner_id => @luke.id)
  end

  it "should delete normally" do
    Android.count_with_destroyed.should == 2
    Android.delete_all
    Android.count_with_destroyed.should == 0
  end

  it "should handle Model.destroy_all properly" do
    lambda{
      Android.destroy_all("owner_id = #{@luke.id}")
    }.should change(Android, :count).from(2).to(0)
    Android.count_with_destroyed.should == 2
  end

  it "should handle Model.destroy(id) properly without hitting update/save related callbacks" do
    lambda{
      Android.destroy(@r2d2.id)
    }.should change(Android, :count).from(2).to(1)

    Android.count_with_destroyed.should == 2
  end

  it "should be not show up in the relationship to the owner once deleted" do
    @luke.androids.size.should == 2
    @r2d2.destroy
    @luke.androids.size.should == 1
    Android.count.should == 1
    Android.first(:conditions => {:name => 'R2D2'}).should be_blank
  end

  it "should be able to find deleted items via find_with_destroyed" do
    @r2d2.destroy
    Android.find(:first, :conditions => {:name => 'R2D2'}).should be_blank
    Android.first_with_destroyed(:conditions => {:name => 'R2D2'}).should_not be_blank
  end

  it "should be able to find only deleted items via find_destroyed_only" do
    @r2d2.destroy
    Android.all_destroyed_only.size.should == 1
    Android.first_destroyed_only.should == @r2d2
  end

  it "should have a proper count inclusively and exclusively of deleted items" do
    @r2d2.destroy
    @c3p0.destroy
    Android.count.should == 0
    Android.count_with_destroyed.should == 2
  end

  it "should mark deleted on dependent destroys" do
    lambda{
      @luke.destroy
    }.should change(Android, :count).from(2).to(0)
    Android.count_with_destroyed.should == 2
  end

  it "should allow restoring without hitting update/save related callbacks" do
    @r2d2.destroy
    lambda{
      @r2d2.restore
    }.should change(Android, :count).from(1).to(2)
  end

  it "should respond to various calculations" do
    @r2d2.destroy
    Android.sum('id').should == @c3p0.id
    Android.sum_with_destroyed('id').should == @r2d2.id + @c3p0.id

    Android.average_with_destroyed('id').should == (@r2d2.id + @c3p0.id) / 2.0
  end

  it "should not ignore deleted items in validation checks unless scoped" do
    # Androids are not validates_uniqueness_of scoped
    @r2d2.destroy
    lambda{
      Android.create!(:name => 'R2D2')
    }.should raise_error(ActiveRecord::RecordInvalid)

    lambda{
      # creating shouldn't raise an error
      another_r2d2 = AndroidWithScopedUniqueness.create!(:name => 'R2D2')
      # neither should destroying the second incarnation since the
      # validates_uniqueness_of is only applied on create
      another_r2d2.destroy
    }.should_not raise_error
  end
  
  it "should allow specifying alternate fields and field values" do
    ninja = Ninja.create(:name => 'Esteban')
    ninja.destroy
    Ninja.first.should be_blank
    Ninja.find_with_destroyed(:first).should == ninja
    
    pirate = Pirate.create(:name => 'Reginald')
    pirate.destroy
    Pirate.first.should be_blank
    Pirate.find_with_destroyed(:first).should == pirate

    DeadPirate.first.id.should == pirate.id
    lambda{
      DeadPirate.first.destroy
    }.should change(Pirate, :count).from(0).to(1)
  end
end