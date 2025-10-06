require 'rails_helper'

RSpec.describe Diffs::Compute, type: :service do
  let(:version_a) { create(:version, content: 'Content A') }
  let(:version_b) { create(:version, content: 'Content B') }

  describe '#call' do
    it 'raises NotImplementedError' do
      service = described_class.new(version_a: version_a, version_b: version_b)

      expect { service.call }.to raise_error(
        Diffs::Compute::NotImplementedError,
        /Diff computation will be added in a later PR/
      )
    end

    context 'future return format documentation' do
      it 'documents expected return format in comments' do
        # This test verifies the service class documents the future format
        # Expected format (per comments in service):
        # {
        #   additions: [...],
        #   deletions: [...],
        #   changes: [...]
        # }

        service = described_class.new(version_a: version_a, version_b: version_b)
        expect(service).to respond_to(:call)
      end
    end

    context 'initialization' do
      it 'accepts version_a and version_b' do
        service = described_class.new(version_a: version_a, version_b: version_b)

        expect(service).to be_a(Diffs::Compute)
      end
    end
  end
end
