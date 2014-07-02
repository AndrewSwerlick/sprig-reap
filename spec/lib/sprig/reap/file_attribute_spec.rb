require 'spec_helper'

describe Sprig::Reap::FileAttribute do
  let!(:user) do
    User.create(:first_name => 'Bo',
                :last_name  => 'Janglez',
                :avatar     => File.open('spec/fixtures/images/avatar.png'))
  end

  let!(:carrierwave) { described_class.new(user.avatar) }
  let!(:not_a_file)  { described_class.new(user.first_name) }

  before do
    stub_rails_root
    Sprig::Reap.stub(:target_env).and_return('dreamland')
  end

  after do
    FileUtils.remove_dir('./uploads') # Generated by CarrierWave
  end

  describe "#file" do
    around do |example|
      setup_seed_folder('./spec/fixtures/db/seeds/dreamland/files', &example)
    end

    context "when the given input is a carrierwave uploader" do
      subject { carrierwave }

      its(:file) { should be_an_instance_of(Sprig::Reap::FileAttribute::LocalFile) }
    end

    context "when the given input is not a recognized file object" do
      subject { not_a_file }

      its(:file) { should == nil }
    end
  end

  describe "#file?" do
    context "when the given input is a carrierwave uploader" do
      subject { carrierwave }

      its(:file?) { should == true }
    end

    context "when the given input is not a recognized file object" do
      subject { not_a_file }

      its(:file?) { should == false }
    end
  end

  describe "#existing_location" do
    subject { carrierwave }

    context "for a locally-stored file" do
      its(:existing_location) { should == subject.input.path }
    end

    context "for a remotely-stored file" do
      before { mock_remote subject }

      its(:existing_location) { should == sprig_logo_url }
    end
  end

  describe "#filename" do
    subject { carrierwave }

    context "for a locally-stored file" do
      its(:filename) { should == 'avatar.png' }
    end

    context "for a remotely-stored file" do
      before { mock_remote subject }

      its(:filename) { should == File.basename(sprig_logo_url) }
    end
  end

  describe "#target_location" do
    subject { carrierwave }

    around do |example|
      setup_seed_folder('./spec/fixtures/db/seeds/dreamland/files', &example)
    end

    its(:target_location) { should == Rails.root.join('db', 'seeds', 'dreamland', 'files', subject.filename) }
  end

  describe "#local_file" do
    around do |example|
      setup_seed_folder('./spec/fixtures/db/seeds/dreamland/files', &example)
    end

    context "when the existing location is a url" do
      subject { carrierwave }

      let(:local_file) { subject.local_file }

      before do
        mock_remote subject
      end

      it "returns a LocalFile" do
        local_file.should be_an_instance_of(Sprig::Reap::FileAttribute::LocalFile)
      end

      it "creates a file at the target location" do
        local_file.path.should == subject.target_location.to_s
      end

      it "creates a file with the same contents as the file from the existing location" do
        File.open(local_file.path, 'r') do |local_file|
          open(subject.existing_location) do |existing_file|
            local_file.should be_same_file_as(existing_file)
          end
        end
      end

      context "and a file already exists at the target location" do
        before do
          File.stub(:exist?).with(subject.target_location).and_return(true)
        end

        it "assigns a unique filename" do
          local_file.path.should_not == subject.target_location.to_s
        end
      end
    end

    context "when the existing location is a path" do
      subject { carrierwave }

      let(:local_file) { subject.local_file }

      it "returns a LocalFile" do
        local_file.should be_an_instance_of(Sprig::Reap::FileAttribute::LocalFile)
      end

      it "creates a file at the target location" do
        local_file.path.should == subject.target_location.to_s
      end

      it "creates a file with the same contents as the file from the existing location" do
        File.open(local_file.path, 'r') do |local_file|
          File.open(subject.existing_location, 'r') do |existing_file|
            local_file.should be_same_file_as(existing_file)
          end
        end
      end

      context "and a file already exists at the target location" do
        before do
          File.stub(:exist?).with(subject.target_location).and_return(true)
        end

        it "assigns a unique filename" do
          local_file.path.should_not == subject.target_location.to_s
        end
      end
    end
  end

  def mock_remote(file_attr)
    file_attr.input.stub(:url).and_return(sprig_logo_url)
  end

  def sprig_logo_url
    'https://camo.githubusercontent.com/ac48b093dc90330d2b9f3bb59671d384fe092166/687474703a2f2f692e696d6775722e636f6d2f5843753369564f2e706e67'
  end
end
