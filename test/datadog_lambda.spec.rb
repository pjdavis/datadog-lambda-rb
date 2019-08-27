# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

require 'datadog_lambda'

describe Datadog::Lambda do
  context 'wrap' do
    it 'should return the same value as returned by the block' do
      event = '1'
      context = '2'
      res = Datadog::Lambda.wrap(event, context) do
        { result: 100 }
      end
      expect(res[:result]).to be 100
    end
    it 'should raise an error if the block raises an error' do
      error_raised = false
      begin
        Datadog::Lambda.wrap(event, context) do
          raise 'Error'
        end
      rescue StandardError
        error_raised = true
      end
      expect(error_raised).to be true
    end
  end
  context 'trace_context' do
    it 'should return the last trace context' do
      event = {
        'headers' => {
          'x-datadog-trace-id' => '12345',
          'x-datadog-parent-id' => '45678',
          'x-datadog-sampling-priority' => '2'
        }
      }
      context = '2'
      Datadog::Lambda.wrap(event, context) do
        { result: 100 }
      end
      expect(Datadog::Lambda.trace_context).to eq(
        trace_id: '12345',
        parent_id: '45678',
        sample_mode: 2
      )
    end
  end

  context 'metric' do
    it 'prints a custom metric' do
      now = Time.utc(2008, 7, 8, 9, 10)
      # rubocop:disable Metrics/LineLength
      output = '{"e":121550820000,"m":"m1","t":["dd_lambda_layer:datadog-ruby25","t.a:val","t.b:v2"],"v":100}'
      # rubocop:enable Metrics/LineLength
      expect(Time).to receive(:now).and_return(now)
      expect do
        Datadog::Lambda.metric('m1', 100, "t.a": 'val', "t.b": 'v2')
      end.to output("#{output}\n").to_stdout
    end
    it 'prints a custom metric with a custom timestamp' do
      now = Time.utc(2008, 7, 8, 9, 10)
      # rubocop:disable Metrics/LineLength
      output = '{"e":121550820000,"m":"m1","t":["dd_lambda_layer:datadog-ruby25","t.a:val","t.b:v2"],"v":100}'
      # rubocop:enable Metrics/LineLength
      expect do
        Datadog::Lambda.metric('m1', 100, time: now, "t.a": 'val', "t.b": 'v2')
      end.to output("#{output}\n").to_stdout
    end
  end
end

# rubocop:enable Metrics/BlockLength