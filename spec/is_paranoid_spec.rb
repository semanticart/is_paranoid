require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/models')

LUKE = 'Luke Skywalker'

describe IsParanoid do
  before(:each) do
    Android.delete_all
    Person.delete_all
    Component.delete_all

    @luke = Person.create(:name => LUKE)
    @r2d2 = Android.create(:name => 'R2D2', :owner_id => @luke.id)
    @c3p0 = Android.create(:name => 'C3P0', :owner_id => @luke.id)

    @r2d2.components.create(:name => 'Rotors')

    @r2d2.memories.create(:name => 'A pretty sunset')
    @c3p0.sticker = Sticker.create(:name => 'OMG, PONIES!')
    @tatooine = Place.create(:name => "Tatooine")
    @r2d2.places << @tatooine
  end

  describe 'non-is_paranoid models' do
    it "should destroy as normal" do
      lambda{
        @luke.destroy
      }.should change(Person, :count).by(-1)

      lambda{
        Person.count_with_destroyed
      }.should raise_error(NoMethodError)
    end
  end

  describe 'destroying' do
    it "should soft-delete a record" do
       lambda{
         Android.destroy(@r2d2.id)
       }.should change(Android, :count).from(2).to(1)
       Android.count_with_destroyed.should == 2
    end

    it "should not hit update/save related callbacks" do
      lambda{
        Android.first.update_attribute(:name, 'Robocop')
      }.should raise_error

      lambda{
        Android.first.destroy
      }.should_not raise_error
    end

    it "should soft-delete matching items on Model.destroy_all" do
      lambda{
        Android.destroy_all("owner_id = #{@luke.id}")
      }.should change(Android, :count).from(2).to(0)
      Android.count_with_destroyed.should == 2
    end

    describe 'related models' do
      it "should no longer show up in the relationship to the owner" do
        @luke.androids.size.should == 2
        @r2d2.destroy
        @luke.androids.size.should == 1
      end

      it "should soft-delete on dependent destroys" do
        lambda{
          @luke.destroy
        }.should change(Android, :count).from(2).to(0)
        Android.count_with_destroyed.should == 2
      end

      it "shouldn't have problems with has_many :through relationships" do
        # TODO: this spec can be cleaner and more specific, replace it later
        # Dings use a boolean non-standard is_paranoid field
        # Scratch uses the defaults.  Testing both ensures compatibility
        [[:dings, Ding], [:scratches, Scratch]].each do |method, klass|
          @r2d2.dings.should == []

          dent = Dent.create(:description => 'really terrible', :android_id => @r2d2.id)
          item = klass.create(:description => 'quite nasty', :dent_id => dent.id)
          @r2d2.reload
          @r2d2.send(method).should == [item]

          dent.destroy
          @r2d2.reload
          @r2d2.send(method).should == []
        end
      end

      it "should not choke has_and_belongs_to_many relationships" do
        @r2d2.places.should include(@tatooine)
        @tatooine.destroy
        @r2d2.reload
        @r2d2.places.should_not include(@tatooine)
        Place.all_with_destroyed.should include(@tatooine)
      end
    end
  end

  describe 'finding destroyed models' do
    it "should be able to find destroyed items via #find_with_destroyed" do
      @r2d2.destroy
      Android.find(:first, :conditions => {:name => 'R2D2'}).should be_blank
      Android.first_with_destroyed(:conditions => {:name => 'R2D2'}).should_not be_blank
    end

    it "should be able to find only destroyed items via #find_destroyed_only" do
      @r2d2.destroy
      Android.all_destroyed_only.size.should == 1
      Android.first_destroyed_only.should == @r2d2
    end

    it "should not show destroyed models via :include" do
      Person.first(:conditions => {:name => LUKE}, :include => :androids).androids.size.should == 2
      @r2d2.destroy
      person = Person.first(:conditions => {:name => LUKE}, :include => :androids)
      # ensure that we're using the preload and not loading it via a find
      Android.should_not_receive(:find)
      person.androids.size.should == 1
    end
  end

  describe 'calculations' do
    it "should have a proper count inclusively and exclusively of destroyed items" do
      @r2d2.destroy
      @c3p0.destroy
      Android.count.should == 0
      Android.count_with_destroyed.should == 2
    end

    it "should respond to various calculations" do
      @r2d2.destroy
      Android.sum('id').should == @c3p0.id
      Android.sum_with_destroyed('id').should == @r2d2.id + @c3p0.id
      Android.average_with_destroyed('id').should == (@r2d2.id + @c3p0.id) / 2.0
    end
  end

  describe 'deletion' do
    it "should actually remove records on #delete_all" do
      lambda{
        Android.delete_all
      }.should change(Android, :count_with_destroyed).from(2).to(0)
    end

    it "should actually remove records on #delete" do
      lambda{
        Android.first.delete
      }.should change(Android, :count_with_destroyed).from(2).to(1)
    end
  end

  describe 'restore' do
    it "should allow restoring soft-deleted items" do
      @r2d2.destroy
      lambda{
        @r2d2.restore
      }.should change(Android, :count).from(1).to(2)
    end

    it "should not hit update/save related callbacks" do
      @r2d2.destroy

      lambda{
        @r2d2.update_attribute(:name, 'Robocop')
      }.should raise_error

      lambda{
        @r2d2.restore
      }.should_not raise_error
    end

    it "should restore dependent models when being restored by default" do
      @r2d2.destroy
      lambda{
        @r2d2.restore
      }.should change(Component, :count).from(0).to(1)
    end

    it "should provide the option to not restore dependent models" do
      @r2d2.destroy
      lambda{
        @r2d2.restore(:include_destroyed_dependents => false)
      }.should_not change(Component, :count)
    end

    it "should restore parent and child models specified via :include" do
      sub_component = SubComponent.create(:name => 'part', :component_id => @r2d2.components.first.id)
      @r2d2.destroy
      SubComponent.first(:conditions => {:id => sub_component.id}).should be_nil
      @r2d2.components.first.restore(:include => [:android, :sub_components])
      SubComponent.first(:conditions => {:id => sub_component.id}).should_not be_nil
      Android.find(@r2d2.id).should_not be_nil
    end
  end

  describe 'validations' do
    it "should not ignore destroyed items in validation checks unless scoped" do
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
  end

  describe '(parent)_with_destroyed' do
    it "should be able to access destroyed parents" do
      # Memory is has_many with a non-default primary key
      # Sticker is a has_one with a default primary key
      [Memory, Sticker].each do |klass|
        instance = klass.last
        parent = instance.android
        instance.android.destroy

        # reload so the model doesn't remember the parent
        instance.reload
        instance.android.should == nil
        instance.android_with_destroyed.should == parent
      end
    end

		it "should be able to access destroyed children" do
			comps = @r2d2.components
			comps.to_s # I have no idea why this makes it pass, but hey, here it is
			@r2d2.components.first.destroy
			@r2d2.components_with_destroyed.should == comps
		end

    it "should return nil if no destroyed parent exists" do
      sticker = Sticker.new(:name => 'Rainbows')
      # because the default relationship works this way, i.e.
      sticker.android.should == nil
      sticker.android_with_destroyed.should == nil
    end

    it "should not break method_missing's defined before the is_paranoid call" do
      # we've defined a method_missing on Sticker
      # that changes the sticker name.
      sticker = Sticker.new(:name => "Ponies!")
      lambda{
        sticker.some_crazy_method_that_we_certainly_do_not_respond_to
      }.should change(sticker, :name).to(Sticker::MM_NAME)
    end
  end

  describe 'alternate fields and field values' do
    it "should properly function for boolean values" do
      # ninjas are invisible by default.  not being ninjas, we can only
      # find those that are visible
      ninja = Ninja.create(:name => 'Esteban', :visible => true)
      ninja.vanish # aliased to destroy
      Ninja.first.should be_blank
      Ninja.find_with_destroyed(:first).should == ninja
      Ninja.count.should == 0

      # we're only interested in pirates who are alive by default
      pirate = Pirate.create(:name => 'Reginald')
      pirate.destroy
      Pirate.first.should be_blank
      Pirate.find_with_destroyed(:first).should == pirate
      Pirate.count.should == 0

      # we're only interested in pirates who are dead by default.
      # zombie pirates ftw!
      DeadPirate.first.id.should == pirate.id
      lambda{
        DeadPirate.first.destroy
      }.should change(Pirate, :count).from(0).to(1)
      DeadPirate.count.should == 0
    end
  end

  describe 'after_destroy and before_destroy callbacks' do
    it "should rollback if before_destroy fails" do
      edward = UndestroyablePirate.create(:name => 'Edward')
      lambda{
        edward.destroy
      }.should_not change(UndestroyablePirate, :count)
    end

    it "should rollback if after_destroy raises an error" do
      raul = RandomPirate.create(:name => 'Raul')
      lambda{
        begin
          raul.destroy
        rescue => ex
          ex.message.should == 'after_destroy works'
        end
      }.should_not change(RandomPirate, :count)
    end

    it "should handle callbacks normally assuming no failures are encountered" do
      component = Component.first
      lambda{
        component.destroy
      }.should change(component, :name).to(Component::NEW_NAME)
    end

  end

  describe "alternate primary key" do
    it "should destroy without problem" do
      uuid = Uuid.create(:name => "foo")
      uuid.destroy.should be_true
    end
  end
end
