Rails.application.routes.draw do

  #web display
  root 'registe#index'

  get 'admin_manage/sign_index' => 'admin_manage#sign_index'
  get 'admin_manage/sign_in' => 'admin_manage#sign_in'
  post 'admin_manage/sign_in' => 'admin_manage#sign_in'
  post 'admin_manage/sign_out' => 'admin_manage#sign_out'

  get 'registe/index' => 'registe#index'
  get 'finance_water/:userid/show' => 'finance_water#show', as: :show_user_score
  get 'pay/:userid/show' => 'online_pay#show', as: :show_user_online_pay
  get 'pay/:online_pay_id/show_single_detail' => 'online_pay#show_single_detail', as: :show_single_online_pay
  get 'transaction_reconciliation/index' => 'transaction_reconciliation#index'
  get 'transaction_reconciliation/index_by_condition' => 'transaction_reconciliation#index_by_condition'
  get 'upload_file/index' => 'upload_file#index'
  post 'upload_file/upload' => 'upload_file#upload'

  #online_pay inteface use 
  post 'registe' => 'registe#create'
  post 'finance_water/:userid/modify' => 'finance_water#modify'
  post 'pay/:userid/submit' => 'online_pay#submit'
  post 'pay/:userid/submit_creditcard' => 'online_pay#submit_creditcard'

  get 'pay/callback/alipay_oversea_return' => 'online_pay_callback#alipay_oversea_return'
  post 'pay/callback/alipay_oversea_notify' => 'online_pay_callback#alipay_oversea_notify'

  get 'pay/callback/alipay_transaction_return' => 'online_pay_callback#alipay_transaction_return'
  post 'pay/callback/alipay_transaction_notify' => 'online_pay_callback#alipay_transaction_notify'

  get 'pay/callback/paypal_return' => 'online_pay_callback#paypal_return'
  get 'pay/callback/paypal_abort' => 'online_pay_callback#paypal_abort'

  get 'pay/callback/sofort_return' => 'online_pay_callback#sofort_return'
  get 'pay/callback/sofort_abort' => 'online_pay_callback#sofort_abort'
  post 'pay/callback/sofort_notify' => 'online_pay_callback#sofort_notify'

  #reconciliation inteface use 
  get 'pay/:payment_system/get_reconciliation' => 'online_pay#get_bill_from_payment_system'


 
  #web display  ---  simulate interface 
  get 'simulation' => 'simulation#index'
  post 'simulation/simulate_pay' => 'simulation#simulate_pay'
  post 'simulation/simulate_pay_credit' => 'simulation#simulate_pay_credit'
  post 'simulation/simulate_post' => 'simulation#simulate_post'
  post 'simulation/simulate_get' => 'simulation#simulate_get'
  post 'simulation/simulate_finance_modify' => 'simulation#simulate_finance_modify'
  post 'simulation/simulate_registe' => 'simulation#simulate_registe'

  get 'simulation/callback_return' => 'simulation#callback_return'
  post 'simulation/callback_notify' => 'simulation#callback_notify'
  
  #reconciliation inteface call
  get 'simulation/simulate_reconciliation' => 'simulation#index_reconciliation'
  post 'simulation/simulate_reconciliation' => 'simulation#simulate_reconciliation'
  
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end