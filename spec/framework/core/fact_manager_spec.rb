# frozen_string_literal: true

describe Facter::FactManager do
  let(:internal_manager) { instance_spy(Facter::InternalFactManager) }
  let(:external_manager) { instance_spy(Facter::ExternalFactManager) }
  let(:cache_manager) { instance_spy(Facter::CacheManager) }
  let(:logger) { instance_spy(Facter::Log) }

  def stub_query_parser(withs, returns)
    allow(Facter::QueryParser).to receive(:parse).with(*withs).and_return(returns)
  end

  def stub_internal_manager(withs, returns)
    allow(internal_manager).to receive(:resolve_facts).with(withs).and_return(returns)
  end

  def stub_external_manager(withs, returns)
    allow(external_manager).to receive(:resolve_facts).with(withs).and_return(returns)
  end

  def stub_cache_manager(withs, returns)
    allow(cache_manager).to receive(:resolve_facts).with(withs).and_return([withs, Array(returns)])
    allow(cache_manager).to receive(:cache_facts)
  end

  before do
    Singleton.__init__(Facter::FactManager)
    Singleton.__init__(Facter::FactLoader)

    allow(Facter::Log).to receive(:new).and_return(logger)
    allow(Facter::InternalFactManager).to receive(:new).and_return(internal_manager)
    allow(Facter::ExternalFactManager).to receive(:new).and_return(external_manager)
    allow(Facter::CacheManager).to receive(:new).and_return(cache_manager)
  end

  describe '#resolve_facts' do
    let(:os) { 'os' }
    let(:os_klass) { instance_double(Facts::Linux::Os::Name) }
    let(:user_query) { [] }
    let(:loaded_facts) do
      [
        instance_double(Facter::LoadedFact, name: 'os.name', klass: os_klass, type: :core),
        instance_double(Facter::LoadedFact, name: 'custom_fact', klass: nil, type: :custom)
      ]
    end

    let(:searched_facts) do
      [
        instance_double(
          Facter::SearchedFact,
          name: os, klass: os_klass, filter_tokens: [],
          user_query: '', type: :core
        ),
        instance_double(
          Facter::SearchedFact,
          name: 'my_custom_fact', klass: nil,
          filter_tokens: [], user_query: '', type: :custom
        )
      ]
    end

    let(:resolved_fact) { mock_resolved_fact(os, 'Ubuntu', '', []) }

    before do
      allow(Facter::FactLoader.instance).to receive(:load).and_return(loaded_facts)
      stub_query_parser([user_query, loaded_facts], searched_facts)
      stub_internal_manager(searched_facts, [resolved_fact])
      stub_external_manager(searched_facts, nil)
      stub_cache_manager(searched_facts, [])
    end

    it 'resolved all facts' do
      resolved_facts = Facter::FactManager.instance.resolve_facts(user_query)

      expect(resolved_facts).to eq([resolved_fact])
    end
  end

  describe '#resolve_fact' do
    context 'with custom fact' do
      let(:user_query) { 'custom_fact' }
      let(:fact_name) { 'custom_fact' }
      let(:custom_fact) { instance_double(Facter::LoadedFact, name: fact_name, klass: nil, type: :custom) }
      let(:loaded_facts) { [custom_fact] }

      let(:searched_facts) do
        [
          instance_double(
            Facter::SearchedFact,
            name: fact_name, klass: nil,
            filter_tokens: [], user_query: '', type: :custom
          )
        ]
      end

      let(:resolved_fact) { mock_resolved_fact(fact_name, 'custom', '', [], :custom) }
      let(:cached_fact) { mock_resolved_fact(fact_name, 'cached_custom', '', [], :custom) }

      context 'when is found in custom_dir/fact_name.rb' do
        before do
          # mock custom_fact_by_filename to return resolved_fact
          allow(Facter::FactLoader.instance).to receive(:load_custom_fact).and_return(loaded_facts)
          stub_query_parser([[user_query], loaded_facts], searched_facts)
          stub_internal_manager(searched_facts, [resolved_fact])
          stub_external_manager(searched_facts, [resolved_fact])
          stub_cache_manager(searched_facts, [])
        end

        it 'tries to load it from fact_name.rb' do
          Facter::FactManager.instance.resolve_fact(user_query)

          expect(logger).to have_received(:debug)
            .with("Searching fact: #{user_query} in file: #{user_query}.rb")
        end

        it 'does not load core and external facts' do
          Facter::FactManager.instance.resolve_fact(user_query)

          expect(logger).not_to have_received(:debug)
            .with("Searching fact: #{user_query} in core facts and external facts")
        end

        it 'does not load all custom facts' do
          Facter::FactManager.instance.resolve_fact(user_query)

          expect(logger).not_to have_received(:debug)
            .with("Searching fact: #{user_query} in all custom facts")
        end

        it 'resolves fact' do
          resolved_facts = Facter::FactManager.instance.resolve_fact(user_query)

          expect(resolved_facts).to eql([resolved_fact])
        end
      end

      context 'when is not found in custom_dir/fact_name.rb' do
        before do
          # mock custom_fact_by_filename to return nil
          allow(Facter::FactLoader.instance).to receive(:load_custom_fact).and_return([])
          stub_query_parser([[user_query], []], [])
          stub_external_manager(searched_facts, [])
          stub_cache_manager([], [])

          # mock core_or_external_fact to return nil
          allow(Facter::FactLoader.instance).to receive(:load_internal_facts).and_return([])
          stub_query_parser([[user_query], []], [])
          stub_internal_manager([], [])
          stub_external_manager([], [])
          stub_cache_manager([], [])

          # mock all_custom_facts to return resolved_fact
          allow(Facter::FactLoader.instance).to receive(:load_custom_facts).and_return(loaded_facts)
          stub_query_parser([[user_query], loaded_facts], searched_facts)
          stub_external_manager(searched_facts, [resolved_fact])
          stub_cache_manager(searched_facts, [])
        end

        it 'tries to load it from fact_name.rb' do
          Facter::FactManager.instance.resolve_fact(user_query)

          expect(logger).to have_received(:debug)
            .with("Searching fact: #{user_query} in file: #{user_query}.rb")
        end

        it 'loads core and external facts' do
          Facter::FactManager.instance.resolve_fact(user_query)

          expect(logger).to have_received(:debug)
            .with("Searching fact: #{user_query} in core facts and external facts")
        end

        it 'loads all custom facts' do
          Facter::FactManager.instance.resolve_fact(user_query)

          expect(logger).to have_received(:debug)
            .with("Searching fact: #{user_query} in all custom facts")
        end

        it 'resolves fact' do
          resolved_facts = Facter::FactManager.instance.resolve_fact(user_query)

          expect(resolved_facts).to eql([resolved_fact])
        end
      end

      context 'when fact is cached' do
        before do
          # mock custom_fact_by_filename to return cached_fact
          allow(Facter::FactLoader.instance).to receive(:load_custom_fact).and_return(loaded_facts)
          stub_query_parser([[user_query], loaded_facts], searched_facts)
          stub_internal_manager(searched_facts, [])
          stub_external_manager(searched_facts, [])
          stub_cache_manager(searched_facts, cached_fact)
        end

        it 'returns the cached fact' do
          resolved_facts = Facter::FactManager.instance.resolve_fact(user_query)

          expect(resolved_facts).to eql([cached_fact])
        end
      end
    end

    context 'with core fact' do
      let(:user_query) { 'os.name' }
      let(:os) { 'os' }
      let(:os_klass) { instance_double(Facts::Linux::Os::Name) }
      let(:core_fact) { instance_double(Facter::LoadedFact, name: 'os.name', klass: os_klass, type: :core) }
      let(:loaded_facts) { [core_fact] }

      let(:searched_facts) do
        [
          instance_double(
            Facter::SearchedFact,
            name: os, klass: os_klass, filter_tokens: [],
            user_query: '', type: :core
          )
        ]
      end

      let(:resolved_fact) { mock_resolved_fact('os.name', 'darwin', '', [], :core) }

      before do
        # mock custom_fact_by_filename to return nil
        allow(Facter::FactLoader.instance).to receive(:load_custom_fact).and_return([])
        stub_query_parser([[user_query], []], [])
        stub_external_manager(searched_facts, [])
        stub_cache_manager([], [])

        # mock core_or_external_fact to return the core resolved_fact
        allow(Facter::FactLoader.instance).to receive(:load_internal_facts).and_return(loaded_facts)
        stub_query_parser([[user_query], loaded_facts], searched_facts)
        stub_internal_manager(searched_facts, [resolved_fact])
        stub_external_manager([], [])
        stub_cache_manager(searched_facts, [])
      end

      it 'tries to load it from fact_name.rb' do
        Facter::FactManager.instance.resolve_fact(user_query)

        expect(logger).to have_received(:debug)
          .with("Searching fact: #{user_query} in file: #{user_query}.rb")
      end

      it 'loads core and external facts' do
        Facter::FactManager.instance.resolve_fact(user_query)

        expect(logger).to have_received(:debug)
          .with("Searching fact: #{user_query} in core facts and external facts")
      end

      it 'does not load all custom facts' do
        Facter::FactManager.instance.resolve_fact(user_query)

        expect(logger).not_to have_received(:debug)
          .with("Searching fact: #{user_query} in all custom facts")
      end

      it 'resolves fact' do
        resolved_facts = Facter::FactManager.instance.resolve_fact(user_query)

        expect(resolved_facts).to eql([resolved_fact])
      end
    end

    context 'with non existent fact' do
      let(:user_query) { 'non_existent' }
      let(:fact_name) { 'non_existent' }
      let(:custom_fact) { instance_double(Facter::LoadedFact, name: 'custom_fact', klass: nil, type: :custom) }
      let(:loaded_facts) { [custom_fact] }

      let(:resolved_fact) { mock_resolved_fact(fact_name, 'custom', '', [], :custom) }

      before do
        # mock custom_fact_by_filename to return nil
        allow(Facter::FactLoader.instance).to receive(:load_custom_fact).and_return([])
        stub_query_parser([[user_query], []], [])
        stub_external_manager([], [])
        stub_cache_manager([], [])

        # mock core_or_external_fact to return nil
        allow(Facter::FactLoader.instance).to receive(:load_internal_facts).and_return([])
        stub_query_parser([[user_query], []], [])
        stub_internal_manager([], [])
        stub_external_manager([], [])
        stub_cache_manager([], [])

        # mock all_custom_facts to return nil
        allow(Facter::FactLoader.instance).to receive(:load_custom_facts).and_return([])
        stub_query_parser([[user_query], []], [])
        stub_external_manager([], [])
        stub_cache_manager([], [])
      end

      it 'tries to load it from fact_name.rb' do
        Facter::FactManager.instance.resolve_fact(user_query)

        expect(logger).to have_received(:debug)
          .with("Searching fact: #{user_query} in file: #{user_query}.rb")
      end

      it 'loads core and external facts' do
        Facter::FactManager.instance.resolve_fact(user_query)

        expect(logger).to have_received(:debug)
          .with("Searching fact: #{user_query} in core facts and external facts")
      end

      it 'loads all custom facts' do
        Facter::FactManager.instance.resolve_fact(user_query)

        expect(logger).to have_received(:debug)
          .with("Searching fact: #{user_query} in all custom facts")
      end

      it 'resolves fact' do
        resolved_facts = Facter::FactManager.instance.resolve_fact(user_query)

        expect(resolved_facts).to eql([])
      end
    end
  end

  describe '#resolve_core' do
    let(:user_query) { [] }
    let(:ubuntu_os_name) { class_double(Facts::Linux::Os::Name) }
    let(:loaded_facts) do
      instance_double(Facter::LoadedFact, name: 'os.name', klass: ubuntu_os_name, type: :core)
    end
    let(:searched_fact) do
      instance_double(
        Facter::SearchedFact,
        name: 'os', klass: ubuntu_os_name,
        filter_tokens: [], user_query: '', type: :core
      )
    end
    let(:resolved_fact) { mock_resolved_fact('os', 'Ubuntu', '', []) }

    it 'resolves all core facts' do
      allow(Facter::FactLoader.instance).to receive(:load_internal_facts).and_return(loaded_facts)
      allow(Facter::FactLoader.instance).to receive(:internal_facts).and_return(loaded_facts)

      stub_query_parser([user_query, loaded_facts], [searched_fact])
      stub_internal_manager([searched_fact], [resolved_fact])
      stub_cache_manager([searched_fact], [])

      resolved_facts = Facter::FactManager.instance.resolve_core(user_query)

      expect(resolved_facts).to eq([resolved_fact])
    end
  end
end
