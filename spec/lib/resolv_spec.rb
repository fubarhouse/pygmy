begin
  require 'byebug'
rescue LoadError
end

require 'rspec'

RSpec.describe Dory::Resolv do
  let(:resolv_file) { '/tmp/resolve' }

  let(:ubuntu_resolv_file_contents) do
    %q(
      # Dynamic resolv.conf(5) file for glibc resolver(3) generated by resolvconf(8)
      #     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
      nameserver 10.0.34.17
      nameserver 10.0.34.16
      nameserver 10.0.201.16
      search corp.instructure.com
    ).split("\n").map{|s| s.gsub(/^\s+/, '')}.join("\n")
  end

  let(:fedora_resolv_file_contents) do
    %q(
      #@VPNC_GENERATED@ -- this file is generated by vpnc
      # and will be overwritten by vpnc
      # as long as the above mark is intact
      # Generated by NetworkManager
      search lan corp.instructure.com
      nameserver 10.0.34.17
    ).split("\n").map{|s| s.gsub(/^\s+/, '')}.join("\n")
  end

	let(:fedora_alt_resolv_file_contents) do
    %q(
      # Generated by NetworkManager
      search lan
      nameserver 192.168.11.1
    ).split("\n").map{|s| s.gsub(/^\s+/, '')}.join("\n")
	end

  let(:stub_resolv_file) do
    ->(filename = resolv_file) do
      allow(Dory::Resolv).to receive(:common_resolv_file) { filename }
      allow(Dory::Resolv).to receive(:ubuntu_resolv_file) { filename }
      # make sure we aren't going to over-write the real resolv file
      expect(Dory::Resolv.resolv_file).to eq(filename)
    end
  end

  let(:set_ubuntu) do
    ->() do
      allow(Dory::Linux).to receive(:ubuntu?){ true }
      allow(Dory::Linux).to receive(:fedora?){ false }
      allow(Dory::Linux).to receive(:arch?){ false }
    end
  end

  let(:set_fedora) do
    ->() do
      allow(Dory::Linux).to receive(:ubuntu?){ false }
      allow(Dory::Linux).to receive(:fedora?){ true }
      allow(Dory::Linux).to receive(:arch?){ false }
    end
  end

  let(:set_arch) do
    ->() do
      allow(Dory::Linux).to receive(:ubuntu?){ false }
      allow(Dory::Linux).to receive(:fedora?){ false }
      allow(Dory::Linux).to receive(:arch?){ true }
    end
  end

  let(:set_unknown_platform) do
    ->() do
      allow(Dory::Linux).to receive(:ubuntu?){ false }
      allow(Dory::Linux).to receive(:fedora?){ false }
      allow(Dory::Linux).to receive(:arch?){ false }
    end
  end

  it 'returns common resolv file on fedora and arch' do
    stub_resolv_file.call()
    expect(Dory::Resolv.common_resolv_file).to eq(resolv_file)
    set_fedora.call()
    expect(Dory::Resolv.resolv_file).to eq(resolv_file)
    set_arch.call()
    expect(Dory::Resolv.resolv_file).to eq(resolv_file)
  end

  context "resolv file creation/destruction" do
    let(:filename) { '/tmp/thisfiledefinitelydoesnotexist.noexist' }

    before :each do
      stub_resolv_file.call(filename)
      expect(Dory::Resolv.common_resolv_file).to eq(filename)
      system("rm #{filename}")
      expect(File.exist?(Dory::Resolv.common_resolv_file)).to be_falsey
    end

    it 'returns common resolv file on unknown platform if it exists' do
      expect{
        system("touch #{filename}")
      }.to change{File.exist?(Dory::Resolv.common_resolv_file)}.from(false).to(true)
      set_unknown_platform.call()
      expect(Dory::Resolv.resolv_file).to eq(filename)
      expect{
        system("rm #{filename}")
      }.to change{File.exist?(Dory::Resolv.common_resolv_file)}.from(true).to(false)
      expect{Dory::Resolv.resolv_file}.to raise_error(RuntimeError, /unable.*location.*resolv.*file/i)
    end
  end

  context "editing the file" do
    let(:file_contents) do
      [
        ubuntu_resolv_file_contents,
        fedora_resolv_file_contents,
        fedora_alt_resolv_file_contents,
        "# some comments\n    # more comments\n",
        "\n", # empty file
      ]
    end

    before :each do
      stub_resolv_file.call()
      # To add an extra layer of protection against modifying the
      # real resolv file, make sure it matches
      expect(Dory::Resolv.resolv_file).to eq(resolv_file)
    end

    it "adds the nameserver when it doesn't exist" do
      file_contents.each do |contents|
        File.write(resolv_file, contents)
        expect(Dory::Resolv).not_to have_our_nameserver
        expect{Dory::Resolv.configure}.to change{Dory::Resolv.has_our_nameserver?}.from(false).to(true)
        expect(Dory::Resolv).to have_our_nameserver
      end
    end

    it "doesn't add the nameserver twice" do
      file_contents.each do |contents|
        File.write(resolv_file, contents)
        expect(Dory::Resolv).not_to have_our_nameserver
        expect{Dory::Resolv.configure}.to change{Dory::Resolv.has_our_nameserver?}.from(false).to(true)
        expect(Dory::Resolv).to have_our_nameserver
        lines = Dory::Resolv.resolv_file_contents.split("\n")
        nameserver_found = false
        lines.each do |line|
          if nameserver_found
            expect(line).not_to match(/dory/)
          end
          nameserver_found = true if line =~ /dory/
        end
        expect(nameserver_found).to be_truthy
      end
    end

    it "cleans up properly" do
      file_contents.each do |contents|
        File.write(resolv_file, contents)
        expect(Dory::Resolv).not_to have_our_nameserver
        expect{Dory::Resolv.configure}.to change{Dory::Resolv.has_our_nameserver?}.from(false).to(true)
        expect(Dory::Resolv).to have_our_nameserver
        expect{Dory::Resolv.clean}.to change{Dory::Resolv.has_our_nameserver?}.from(true).to(false)
        expect(Dory::Resolv).not_to have_our_nameserver
        expect(File.read(resolv_file)).to eq(contents)
        expect(Dory::Resolv.resolv_file_contents).to eq(contents)
      end
    end
  end
end