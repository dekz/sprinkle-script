require 'spec_helper'

describe Sprinkle::Actors::Script do

  let(:script) { Sprinkle::Actors::Script.new do; end; }
  let(:package) { Package.new("super") {} }
  let(:io_script) {
    Sprinkle::Actors::Script.new do
      file StringIO.new
    end
  }

  after do
    FileUtils.rm_rf('./tmp') rescue nil
  end

  describe 'attributes' do
    it 'has default values' do
      expect(script.directory).to eq('./tmp')
      expect(script.file.path).to eq('./tmp/install.sh')
    end

    it 'can override default values' do
       s = Sprinkle::Actors::Script.new do
         directory './tmpa'
       end
      expect(s.directory).to eq('./tmpa')
      FileUtils.rm_rf('./tmpa')
    end
  end

  describe 'when installing' do

    let(:installer) { Sprinkle::Installers::Runner.new(package, "echo hi") }
    let(:roles) { %w( app ) }
    let(:commands) { %w( op1 op2 ) }
    let(:name) { 'name' }

    it 'should write the command to a file' do

      script = io_script
      expect(script).to receive(:process).once.and_call_original
      script.install installer, roles

      script.file.rewind
      expect(script.file.read).to match /echo hi/
    end

  end

  describe 'when downloading' do

    def create_binary(binary, version = nil, &block)
      @package = double(Sprinkle::Package, :name => 'package', :version => version)
      Sprinkle::Installers::Binary.new(@package, binary, &block)
    end

    let(:installer) { create_binary 'binary.tar.gz' }
    let(:roles) { %w( app ) }

    it 'should download the binary to disk' do
      script = io_script
      expect(script).to receive(:process).once.and_call_original
      expect(script).to receive(:download_file).once.with('binary.tar.gz', './tmp')
      script.install installer, roles

      script.file.rewind
      # We replace the binary download with a prefetch into the tmp directory
      # Then we extract as normal
      expect(script.file.read).to match /tar xzf \'binary\.tar\.gz\'/
    end

  end

  describe 'pushing text' do

    def create_text(text, path, options={}, &block)
      @package = double(Sprinkle::Package, :name => 'package', :sudo? => false)
      Sprinkle::Installers::PushText.new(@package, text, path, options, &block)
    end

    let(:installer) { create_text 'another-hair-brained-idea', '/dev/mind/late-night' }
    let(:roles) { %w( app ) }

    it 'should download the binary to disk' do
      script = io_script
      expect(script).to receive(:process).once.and_call_original
      script.install installer, roles

      script.file.rewind
      expect(script.file.read).to include(%q[/bin/echo -e 'another-hair-brained-idea' |tee -a /dev/mind/late-night"])
    end

  end

  describe 'transferring files' do

  def create_transfer(source, dest, options={}, &block)
    i = Sprinkle::Installers::Transfer.new(package, source, dest, options, &block)
    i.delivery = delivery
    i
  end

    let(:installer) { create_text 'another-hair-brained-idea', '/dev/mind/late-night' }
    let(:roles) { %w( app ) }
    let(:delivery) {  double(Sprinkle::Deployment, :install => true, :sudo_command => "sudo", :sudo? => false) }
    let(:source) { 'source' }
    let(:destination) { 'destination' }
    let(:installer)  { create_transfer(source, destination) }
    let(:package) { double(Sprinkle::Package, :name => 'package', :sudo? => false) }

    it 'should download the binary to disk' do
      script = io_script
      expect(script).to receive(:process).once.and_call_original
      expect(script).to receive(:copy).once.with(source)
      script.install installer, roles

      script.file.rewind
      expect(script.file.read).to include(%Q[cp #{source} #{destination}])
    end

  end
end
