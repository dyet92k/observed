require 'spec_helper'

require 'observed/gauge'
require 'observed/system'

shared_examples_for 'the observed-gauge plugin' do

  subject {
    described_class.new
  }

  before {
    File.delete(rrd) if File.exist?(rrd)

    subject.configure rrd: rrd, key_path: key_path
  }

  it 'matches against the tag using a pattern described in regular expression' do
    expect(subject.match('test.foo')).to be_true
  end

  it 'reports data with averaged values' do
    subject.prepare_rrd(start: t - 120, rrd: rrd)
    system.expects(:report).with(tag, t, expected_data.freeze).once
    expect { system.translate('test.foo', t - 120, data) }.to_not raise_error
    expect { system.translate('test.foo', t - 60, data) }.to_not raise_error
    expect { system.translate('test.foo', t, data) }.to_not raise_error
  end

  it 'creates rrd files automatically on first report' do
    expect { subject.translate('test.foo', t, data) }.to_not raise_error

    expect { File.exist? rrd }.to be_true
  end
end

describe Observed::Plugins::Gauge do
  subject {
    Observed::Plugins::Gauge.new
  }

  it 'has a name' do
    expect(described_class.plugin_name).to eq('gauge')
  end

  context 'with configuration' do

    before {

      subject.configure(
          system: system,
          tag_pattern: tag_pattern,
          tag: tag,
          step: step,
          period: period
      )
    }

    after {
      File.delete(rrd) if File.exist?(rrd)
    }

    let(:t) {
      Time.now
    }

    let(:system) {
      sys = Observed::System.new

      sys.stubs(:translators).returns([subject])
      sys.stubs(:now).returns(t)

      sys
    }

    let(:tag_pattern) {
      /test.\.*/
    }

    let(:tag) {
      'test.out'
    }

    let(:step) {
      10
    }

    let(:period) {
      60
    }

    before {
      subject.configure(
          system: system,
          tag_pattern: tag_pattern,
          tag: tag,
          step: step,
          period: period,
          key_path: key_path
      )
    }

    context 'with an incorrect key path' do

      let(:key_path) {
        123
      }

      let(:rrd) {
        'gauge_incorrect_key_path.rrd'
      }

      let(:data) {
        { response: { time: 10 }}
      }

      let(:t) {
        Time.now
      }

      it 'raise an error' do
        expect { system.translate('test.foo', t, data) }.to raise_error(/Unexpected type of key_path met/)
      end
    end

    context 'with a correct key path' do

      let(:key_path) {
        'response.time'
      }

      let(:data_source) {
        'response_time'
      }

      context 'with the default coercer' do

        context 'with data whose keys are symbols' do
          let(:rrd) {
            'gauge_spec_symbols.rrd'
          }

          let(:data) {
            { response: { time: 10 }}
          }

          let(:expected_data) {
            { response: { time: 10 }}
          }

          it_behaves_like 'the observed-gauge plugin'
        end

        context 'with data whose keys are strings' do
          let(:rrd) {
            'gauge_spec_strings.rrd'
          }

          let(:data) {
            {'response' => {'time' => 10}}
          }

          let(:expected_data) {
            { 'response' => { 'time' => 10 }}
          }

          it_behaves_like 'the observed-gauge plugin'
        end

      end

      context 'with a string-to-integer coercer for values' do

        before {
          subject.configure coercer: ->(v){ t.to_i }
        }

        let(:rrd) {
          'gauge_spec_coercer.rrd'
        }

        let(:data) {
          {'response' => {'time' => '10'}}
        }

        let(:expected_data) {
          { 'response' => { 'time' => 10 }}
        }

        it_behaves_like 'the observed-gauge plugin'
      end

    end

  end

end
