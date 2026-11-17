Rails.application.routes.draw do
  # Framework health check: returns 200 if the app boots without exceptions, otherwise 500.
  # Deliberately outside /api/v1 and not part of docs/api-contracts.md.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Routed before /employees/:id so "export" is not parsed as an id.
      get "employees/export", to: "employees#export"
      resources :employees, only: %i[index show] do
        resources :salary_revisions, only: :create
      end
      get "reference_data", to: "reference_data#show"
      get "analytics/summary", to: "analytics#summary"
    end
  end

  # Unknown routes get the contract's 404 body. Keep this last.
  match "*unmatched", to: "application#route_not_found", via: :all
end
