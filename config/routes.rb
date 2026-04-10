# frozen_string_literal: true

Rails.application.routes.draw do
  scope '/admin' do
    get  'login_audit',            to: 'login_audit#index'
    post 'login_audit/delete',     to: 'login_audit#delete'
    post 'login_audit/delete_all', to: 'login_audit#delete_all'
    get  'login_audit/export',     to: 'login_audit#export'
  end
end
