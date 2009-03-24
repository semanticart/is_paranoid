require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class Person < ActiveRecord::Base
  has_many :androids, :foreign_key => :owner_id, :dependent => :destroy
end

class Android < ActiveRecord::Base
  validates_uniqueness_of :name
  is_paranoid :with_calculations => true
end

class NoCalculation < ActiveRecord::Base
  is_paranoid
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

  it "should handle Model.destroy(id) properly" do
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
    Android.find_with_destroyed(:first, :conditions => {:name => 'R2D2'}).should_not be_blank
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

  it "should allow restoring" do
    @r2d2.destroy
    lambda{
      @r2d2.restore
    }.should change(Android, :count).from(1).to(2)
  end

  it "should respond to various calculations if we specify that we want them" do
    NoCalculation.respond_to?(:sum_with_destroyed).should == false
    Android.respond_to?(:sum_with_destroyed).should == true

    @r2d2.destroy
    Android.sum('id').should == @c3p0.id
    Android.sum_with_destroyed('id').should == @r2d2.id + @c3p0.id
  end

  # Note:  this isn't necessarily ideal, this just serves to demostrate
  # how it currently works
  it "should not ignore deleted items in validation checks" do
    @r2d2.destroy
    lambda{
      Android.create!(:name => 'R2D2')
    }.should raise_error(ActiveRecord::RecordInvalid)
  end
end