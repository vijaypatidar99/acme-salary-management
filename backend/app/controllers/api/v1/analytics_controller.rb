module Api
  module V1
    class AnalyticsController < ApplicationController
      def summary
        render json: { data: Analytics::Summary.new(params).call }
      end
    end
  end
end
