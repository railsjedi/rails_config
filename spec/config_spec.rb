require 'spec_helper'

describe Config do

  it "should get setting files" do
    config = Config.setting_files("root/config", "test")
    expect(config).to eq([
                           'root/config/settings.yml',
                           'root/config/settings/test.yml',
                           'root/config/environments/test.yml',
                           'root/config/settings.local.yml',
                           'root/config/settings/test.local.yml',
                           'root/config/environments/test.local.yml'
                         ])
  end

  it "should load a basic config file" do
    config = Config.load_sources("#{fixture_path}/settings.yml")
    expect(config.size).to eq(1)
    expect(config.server).to eq("google.com")
    expect(config['1']).to eq('one')
    expect(config.photo_sizes.avatar).to eq([60, 60])
    expect(config.root['yahoo.com']).to eq(2)
    expect(config.root['google.com']).to eq(3)
  end

  it "should load 2 basic config files" do
    config = Config.load_sources("#{fixture_path}/settings.yml", "#{fixture_path}/settings2.yml")
    expect(config.size).to eq(1)
    expect(config.server).to eq("google.com")
    expect(config.another).to eq("something")
  end

  it "should load empty config for a missing file path" do
    config = Config.load_sources("#{fixture_path}/some_file_that_doesnt_exist.yml")
    expect(config).to be_empty
  end

  it "should load an empty config for multiple missing file paths" do
    files  = ["#{fixture_path}/doesnt_exist1.yml", "#{fixture_path}/doesnt_exist2.yml"]
    config = Config.load_sources(files)
    expect(config).to be_empty
  end

  it "should load empty config for an empty setting file" do
    config = Config.load_sources("#{fixture_path}/empty1.yml")
    expect(config).to be_empty
  end

  it "should convert to a hash" do
    config = Config.load_sources("#{fixture_path}/development.yml").to_hash
    expect(config[:section][:servers]).to be_kind_of(Array)
    expect(config[:section][:servers][0][:name]).to eq("yahoo.com")
    expect(config[:section][:servers][1][:name]).to eq("amazon.com")
  end

  it "should convert to a hash (We Need To Go Deeper)" do
    config  = Config.load_sources("#{fixture_path}/development.yml").to_hash
    servers = config[:section][:servers]
    expect(servers).to eq([{ name: "yahoo.com" }, { name: "amazon.com" }])
  end

  it "should convert to a hash without modifying nested settings" do
    config = Config.load_sources("#{fixture_path}/development.yml")
    config.to_hash
    expect(config).to be_kind_of(Config::Options)
    expect(config[:section]).to be_kind_of(Config::Options)
    expect(config[:section][:servers][0]).to be_kind_of(Config::Options)
    expect(config[:section][:servers][1]).to be_kind_of(Config::Options)
  end

  it "should convert to a json" do
    config = Config.load_sources("#{fixture_path}/development.yml").to_json
    expect(JSON.parse(config)["section"]["servers"]).to be_kind_of(Array)
  end

  it "should load an empty config for multiple missing file paths" do
    files  = ["#{fixture_path}/empty1.yml", "#{fixture_path}/empty2.yml"]
    config = Config.load_sources(files)
    expect(config).to be_empty
  end

  it "should allow overrides" do
    files  = ["#{fixture_path}/settings.yml", "#{fixture_path}/development.yml"]
    config = Config.load_sources(files)
    expect(config.server).to eq("google.com")
    expect(config.size).to eq(2)
  end

  it "should allow full reload of the settings files" do
    files = ["#{fixture_path}/settings.yml"]
    Config.load_and_set_settings(files)
    expect(Settings.server).to eq("google.com")
    expect(Settings.size).to eq(1)

    files = ["#{fixture_path}/settings.yml", "#{fixture_path}/development.yml"]
    Settings.reload_from_files(files)
    expect(Settings.server).to eq("google.com")
    expect(Settings.size).to eq(2)
  end

  it 'should allow loading settings from hash' do
    hash = { some_api_key: 'secret_key' }
    config = Config.load_sources(hash)
    expect(config.some_api_key).to eq('secret_key')
  end

  it 'should override properly settings from both file and hash' do
    file = "#{fixture_path}/settings.yml"
    hash = { some_api_key: 'secret_key', size: 2 }
    config = Config.load_sources(file, hash)
    expect(config.server).to eq('google.com')
    expect(config.some_api_key).to eq('secret_key')
    expect(config.size).to eq(2)
  end

  context "Nested Settings" do
    let(:config) do
      Config.load_sources("#{fixture_path}/development.yml")
    end

    it "should allow nested sections" do
      expect(config.section.size).to eq(3)
    end

    it "should allow configuration collections (arrays)" do
      expect(config.section.servers[0].name).to eq("yahoo.com")
      expect(config.section.servers[1].name).to eq("amazon.com")
    end
  end

  context "Settings with ERB tags" do
    let(:config) do
      Config.load_sources("#{fixture_path}/with_erb.yml")
    end

    it "should evaluate ERB tags" do
      expect(config.computed).to eq(6)
    end

    it "should evaluated nested ERB tags" do
      expect(config.section.computed1).to eq(1)
      expect(config.section.computed2).to eq(2)
    end
  end


  context "Boolean Overrides" do
    let(:config) do
      files = ["#{fixture_path}/bool_override/config1.yml", "#{fixture_path}/bool_override/config2.yml"]
      Config.load_sources(files)
    end

    it "should allow overriding of bool settings" do
      expect(config.override_bool).to eq(false)
      expect(config.override_bool_opposite).to eq(true)
    end
  end

  context "Custom Configuration" do
    it "should have the default settings constant as 'Settings'" do
      expect(Config.const_name).to eq("Settings")
    end

    it "should be able to assign a different settings constant" do
      Config.setup { |config| config.const_name = "Settings2" }

      expect(Config.const_name).to eq("Settings2")
    end
  end

  context "Settings with a type value of 'hash'" do
    let(:config) do
      files = ["#{fixture_path}/custom_types/hash.yml"]
      Config.load_sources(files)
    end

    it "should turn that setting into a Real Hash" do
      expect(config.prices).to be_kind_of(Hash)
    end

    it "should map the hash values correctly" do
      expect(config.prices[1]).to eq(2.99)
      expect(config.prices[5]).to eq(9.99)
      expect(config.prices[15]).to eq(19.99)
      expect(config.prices[30]).to eq(29.99)
    end
  end

  context "Merging hash at runtime" do
    let(:config) { Config.load_sources("#{fixture_path}/settings.yml") }
    let(:hash) { { :options => { :suboption => 'value' }, :server => 'amazon.com' } }

    it 'should be chainable' do
      expect(config.merge!({})).to eq(config)
    end

    it 'should preserve existing keys' do
      expect { config.merge!({}) }.to_not change { config.keys }
    end

    it 'should recursively merge keys' do
      config.merge!(hash)
      expect(config.options.suboption).to eq('value')
    end

    it 'should rewrite a merged value' do
      expect { config.merge!(hash) }.to change { config.server }.from('google.com').to('amazon.com')
    end
  end

  context "Merging nested hash at runtime" do
    let(:config) { Config.load_sources("#{fixture_path}/deep_merge/config1.yml") }
    let(:hash) { { :inner => { :something1 => 'changed1', :something3 => 'changed3' } } }

    it 'should preserve first level keys' do
      expect { config.merge!(hash) }.to_not change { config.keys }
    end

    it 'should preserve nested key' do
      config.merge!(hash)
      expect(config.inner.something2).to eq('blah2')
    end

    it 'should add new nested key' do
      expect { config.merge!(hash) }.to change { config.inner.something3 }.from(nil).to("changed3")
    end

    it 'should rewrite a merged value' do
      expect { config.merge!(hash) }.to change { config.inner.something1 }.from('blah1').to('changed1')
    end
  end

  context "[] accessors" do
    let(:config) do
      files = ["#{fixture_path}/development.yml"]
      Config.load_sources(files)
    end

    it "should access attributes using []" do
      expect(config.section['size']).to eq(3)
      expect(config.section[:size]).to eq(3)
      expect(config[:section][:size]).to eq(3)
    end

    it "should set values using []=" do
      config.section[:foo] = 'bar'
      expect(config.section.foo).to eq('bar')
    end
  end

  context "enumerable" do
    let(:config) do
      files = ["#{fixture_path}/development.yml"]
      Config.load_sources(files)
    end

    it "should enumerate top level parameters" do
      keys = []
      config.each { |key, value| keys << key }
      expect(keys).to eq([:size, :section])
    end

    it "should enumerate inner parameters" do
      keys = []
      config.section.each { |key, value| keys << key }
      expect(keys).to eq([:size, :servers])
    end

    it "should have methods defined by Enumerable" do
      expect(config.map { |key, value| key }).to eq([:size, :section])
    end
  end

  context "keys" do
    let(:config) do
      files = ["#{fixture_path}/development.yml"]
      Config.load_sources(files)
    end

    it "should return array of keys" do
      expect(config.keys).to contain_exactly(:size, :section)
    end

    it "should return array of keys for nested entry" do
      expect(config.section.keys).to contain_exactly(:size, :servers)
    end
  end

  context 'when loading settings files' do
    context 'using knockout_prefix' do
      context 'in configuration phase' do
        it 'should be able to assign a different knockout_prefix value' do
          Config.reset
          Config.knockout_prefix = '--'

          expect(Config.knockout_prefix).to eq('--')
        end

        it 'should have the default knockout_prefix value equal nil' do
          Config.reset

          expect(Config.knockout_prefix).to eq(nil)
        end
      end

      context 'merging' do
        let(:config) do
          Config.knockout_prefix = '--'
          Config.overwrite_arrays = false
          Config.load_sources(["#{fixture_path}/knockout_prefix/config1.yml",
                               "#{fixture_path}/knockout_prefix/config2.yml",
                               "#{fixture_path}/knockout_prefix/config3.yml"])
        end

        it 'should remove elements from settings' do
          expect(config.array1).to eq(['item4', 'item5', 'item6'])
          expect(config.array2.inner).to eq(['item4', 'item5', 'item6'])
          expect(config.array3).to eq('')
          expect(config.string1).to eq('')
          expect(config.string2).to eq('')
          expect(config.hash1.to_hash).to eq({ key1: '', key2: '', key3: 'value3' })
          expect(config.hash2).to eq('')
          expect(config.hash3.to_hash).to eq({ key4: 'value4', key5: 'value5' })
          expect(config.fixnum1).to eq('')
          expect(config.fixnum2).to eq('')
        end
      end
    end

    context 'using overwrite_arrays' do
      context 'in configuration phase' do
        it 'should be able to assign a different overwrite_arrays value' do
          Config.reset
          Config.overwrite_arrays = false

          expect(Config.overwrite_arrays).to eq(false)
        end

        it 'should have the default overwrite_arrays value equal false' do
          Config.reset

          expect(Config.overwrite_arrays).to eq(true)
        end
      end

      context 'overwriting' do
        let(:config) do
          Config.overwrite_arrays = true
          Config.load_sources(["#{fixture_path}/overwrite_arrays/config1.yml",
                               "#{fixture_path}/overwrite_arrays/config2.yml",
                               "#{fixture_path}/overwrite_arrays/config3.yml"])
        end

        it 'should remove elements from settings' do
          expect(config.array1).to eq(['item4', 'item5', 'item6'])
          expect(config.array2.inner).to eq(['item4', 'item5', 'item6'])
          expect(config.array3).to eq([])
        end
      end


      context 'merging' do
        let(:config) do
          Config.overwrite_arrays = false
          Config.load_sources(["#{fixture_path}/deep_merge/config1.yml",
                               "#{fixture_path}/deep_merge/config2.yml"])
        end

        it 'should merge hashes from multiple configs' do
          expect(config.inner.marshal_dump.keys.size).to eq(3)
          expect(config.inner2.inner2_inner.marshal_dump.keys.size).to eq(3)
        end

        it 'should merge arrays from multiple configs' do
          expect(config.arraylist1.size).to eq(6)
          expect(config.arraylist2.inner.size).to eq(6)
        end
      end

    end

    context 'with extra sources' do
      before do
        Config.reset
      end

      context 'in configuration phase' do
        it 'should have empty array as default extra_sources value' do
          expect(Config.extra_sources).to eq([])
        end

        it 'should be able to assign a different extra_sources values' do
          Config.extra_sources = ['extra_config.yml', { some_key: 'some_value' }]

          expect(Config.extra_sources).to eq(['extra_config.yml', { some_key: 'some_value' }])
        end
      end

      context 'merging' do
        let(:hash1) do
          { avatar: { width: 64, height: 64 } }
        end
        let(:hash2) do
          { app_name: 'App',
            external_service: { api_key: 'super_secret_key' }}
        end
        let(:config) do
          Config.load_sources([hash1,
                               "#{fixture_path}/extra_sources/config1.yml",
                               "#{fixture_path}/extra_sources/config2.yml",
                               hash2])
        end
        let(:expected_config) do
          { app_name: 'App',
            external_service: { api_key: 'super_secret_key', items_per_page: 20 },
            avatar: { width: 128, height: 128 }}
        end

        it 'should merge settings from multiple sources' do
          expect(config.to_hash).to eq(expected_config)
        end
      end
    end
  end
end
