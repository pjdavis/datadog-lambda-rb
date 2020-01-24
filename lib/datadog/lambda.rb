# frozen_string_literal: true

#
# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
#
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2019 Datadog, Inc.
#

require 'datadog/lambda/trace/listener'
require 'datadog/lambda/utils/logger'
require 'datadog/lambda/trace/patch_http'
require 'json'
require 'time'

# rubocop:disable Style/GlobalVars
$IS_COLD_START = true
# rubocop:enable Style/GlobalVars

module Datadog
  # Instruments AWS Lambda functions with Datadog distributed tracing and
  # custom metrics
  module Lambda
    # Wrap the body of a lambda invocation
    # @param event [Object] event sent to lambda
    # @param context [Object] lambda context
    # @param block [Proc] implementation of the handler function.
    def self.wrap(event, context, &block)
      Datadog::Utils.update_log_level
      @listener ||= Trace::Listener.new
      @listener.on_start(event: event)
      record_enhanced('invocations', context)
      begin
        res = block.call
      rescue StandardError => e
        record_enhanced('errors', context)
        raise e
      ensure
        @listener.on_end
      end
      # rubocop:disable Style/GlobalVars
      $IS_COLD_START = false
      # rubocop:enable Style/GlobalVars
      res
    end

    # Gets the current tracing context
    def self.trace_context
      Datadog::Trace.trace_context
    end

    # Send a custom distribution metric
    # @param name [String] name of the metric
    # @param value [Numeric] value of the metric
    # @param time [Time] the time of the metric, should be in the past
    # @param tags [Hash] hash of tags, must be in "my.tag.name":"value" format
    def self.metric(name, value, time: nil, **tags)
      raise 'name must be a string' unless name.is_a?(String)
      raise 'value must be a number' unless value.is_a?(Numeric)

      time ||= Time.now
      tag_list = ['dd_lambda_layer:datadog-ruby25']
      tags.each do |tag|
        tag_list.push("#{tag[0]}:#{tag[1]}")
      end
      time_ms = time.to_f.to_i
      metric = { e: time_ms, m: name, t: tag_list, v: value }.to_json
      puts metric
    end

    def self.gen_enhanced_tags(context)
      arn_parts = context.invoked_function_arn.split(':')
      {
        functionname: context.function_name,
        region: arn_parts[3],
        account_id: arn_parts[4],
        memorysize: context.memory_limit_in_mb,
        # rubocop:disable Style/GlobalVars
        cold_start: $IS_COLD_START,
        # rubocop:enable Style/GlobalVars
        runtime: "Ruby #{RUBY_VERSION}"
      }
    end

    def self.record_enhanced(metric_name, context)
      etags = gen_enhanced_tags(context)
      metric(metric_name, 1, etags)
    end
  end
end
