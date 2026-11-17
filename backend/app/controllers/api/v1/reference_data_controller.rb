module Api
  module V1
    class ReferenceDataController < ApplicationController
      def show
        render json: { data: ReferenceDataQuery.call }
      end
    end
  end
end
