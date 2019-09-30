# frozen_string_literal: true

describe 'Sles OsArchitecture' do
  context '#call_the_resolver' do
    it 'returns a fact' do
      expected_fact = double(Facter::ResolvedFact, name: 'os.architecture', value: 'value')
      allow(Facter::Resolvers::Uname).to receive(:resolve).with(:machine).and_return('value')
      allow(Facter::ResolvedFact).to receive(:new).with('os.architecture', 'value').and_return(expected_fact)

      fact = Facter::Sles::OsArchitecture.new
      expect(fact.call_the_resolver).to eq(expected_fact)
    end
  end
end
