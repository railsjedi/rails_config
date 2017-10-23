require 'spec_helper'

if RUBY_VERSION >= '2.1'
  describe Config do
    context 'validation' do
      around(:each) do |example|
        Config.reset
        example.run
        Config.reset
      end

      it 'should raise if schema is present and validation fails' do
        Config.setup do |config|
          config.schema do
            required(:youtube).schema do
              required(:nonexist_field).filled
            end
          end
        end

        expect { Config.load_sources("#{fixture_path}/validation/config.yml") }.
          to raise_error(Config::Validation::Error, /youtube.nonexist_field: is missing/)
      end

      it 'should work if validation passes' do
        Config.setup do |config|
          config.schema do
            required(:youtube).schema do
              required(:api_key).filled
            end
          end
        end

        expect { Config.load_sources("#{fixture_path}/validation/config.yml") }.
          to_not raise_error
      end
    end
  end
end
