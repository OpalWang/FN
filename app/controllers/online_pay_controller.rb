class OnlinePayController < ApplicationController
	protect_from_forgery :except => :submit

	include Paramsable

	before_action :authenticate_admin!,:only=>[:show,:show_single_detail]

	def show
		@user=User.find(params['userid'])
		@online_pays=@user.online_pay.order(created_at: :desc)
	end

	def show_single_detail
		@online_pay=OnlinePay.find(params['online_pay_id'])
	end

	def submit
		render json:{},status:400 and return unless params_valid("online_pay_submit",params)
		ret_hash={
			'redirect_url'=>'',
			'trade_no'=>'',
			'is_credit'=>''
		}

		online_pay=new_online_pay_params(params,request)
		if(online_pay.status=='failure')
			logger.warn("no user:#{online_pay.userid} pay record save!")
			render json:{},status:400 and return
		end
		
		ActiveRecord::Base.transaction do
			begin
				pay_detail=OnlinePay.get_instance_pay_detail(online_pay)

				flag,online_pay.redirect_url,online_pay.trade_no,online_pay.is_credit,message=pay_detail.submit()

				logger.info("#{flag} - #{online_pay.redirect_url} - #{online_pay.trade_no} - #{message}")

				unless(flag=="success")
					online_pay.set_status!("failure_submit",message)
				end
				online_pay.save!
				#alipay trade_no is nil so use  system_orderno
				if(online_pay.trade_no.blank? && flag=="success")
					#online_pay.trade_no="finance_#{online_pay.created_at.strftime("%y%m%d%H%M%S") }_#{online_pay.id}"
					online_pay.trade_no="#{online_pay.system}_#{online_pay.order_no}"
					online_pay.update_attributes!('trade_no'=>online_pay.trade_no)
				end

				ret_hash['redirect_url']=CGI.escape(online_pay.redirect_url)
				ret_hash['trade_no']=online_pay.trade_no
				ret_hash['is_credit']=online_pay.is_credit
			rescue => e
				#failure also save pay record!!
				logger.info("create online_pay failure! : #{e.message}")
				online_pay.set_status!("failure_submit",e.message)
				online_pay.save
				render json:{},status:400 and return
			end
		end

		render json:ret_hash.to_json
	end

	def  submit_creditcard
		render json:{},status:400 and return unless params_valid("online_pay_submit_creditcard",params)
		ret_hash={
			'status'=>'failure',
			'status_reason'=>''
		}

		OnlinePay.transaction do  	#lock table_row
			online_pay=OnlinePay.get_online_pay_instance(params['payway'],params['paytype'],params,["submit_credit"],true,true)
			render json:{},status:400  and return if online_pay.blank?
			
			begin
				supplement_online_pay_credit_params!(online_pay,params)

				pay_detail=OnlinePay.get_instance_pay_detail(online_pay)
				message=pay_detail.valid_credit_require(online_pay,request)
				unless(message=="success")
					raise "require valid failure! #{message}"
				end

				online_pay.set_status!("success_credit","")
				online_pay.save!()
				flag,message,online_pay.reconciliation_id,online_pay.callback_status=pay_detail.process_purchase(online_pay)
					
				if flag==true
					#update reconciliation_id
					ret_hash['status']="success"
					online_pay.save()
				else
					ret_hash['status_reason']=message
					raise "#{message}"
				end	
			rescue => e
				#failure also save pay record!!	
				logger.info("submit_creditcard online_pay failure! : #{e.message}")
				#online_pay.set_status!("failure_credit",e.message)
				online_pay.update_attributes(:status=>"failure_credit",:reason=>e.message)
				render json:{},status:400 and return
			end
		end

		render json:ret_hash.to_json
	end

	def get_bill_from_payment_system
		payment_system=params['payment_system']
		case payment_system
		when "alipay_transaction" then  reconciliation=ReconciliationAlipayTransaction.new("account.page.query")
		when "alipay_oversea" then  reconciliation=ReconciliationAlipayOversea.new("forex_compare_file")
			# if payment_system_sub=="transaction"
			# 	reconciliation=ReconciliationAlipayTransaction.new("account.page.query","","",10)
			# else
			# 	nil
			# end
		when "paypal" then reconciliation=ReconciliationPaypal.new("TransactionSearch")
		else
			render :text=>"wrong payment_system #{payment_system}" and return
		end

		#call interface  and   finance reconciliation
		message=reconciliation.finance_reconciliation()

		render :text=>message
	end

	private 
		def new_online_pay_params(params,request)
			user=User.find_by_system_and_userid(params['system'],params['userid'])
			if(user.blank?)
				online_pay=OnlinePay.new()
				online_pay.set_status!("failure_submit","user not exists")
			else
				online_pay=user.online_pay.build()
				online_pay.set_status!("submit","")
			end

			online_pay.system=params.delete('system')
			online_pay.channel=params.delete('channel')
			online_pay.userid=params.delete('userid')
			online_pay.payway=params.delete('payway')
			online_pay.paytype=params.delete('paytype')
			online_pay.amount=params.delete('amount')
			online_pay.currency=params.delete('currency')
			online_pay.order_no=params.delete('order_no')
			online_pay.success_url=params.delete('success_url')
			online_pay.notification_url=params.delete('notification_url')
			online_pay.notification_email=params.delete('notification_email')
			online_pay.abort_url=params.delete('abort_url')
			online_pay.timeout_url=params.delete('timeout_url')
			online_pay.ip=params.delete('ip')
			online_pay.description=params.delete('description')
			online_pay.country=params.delete('country')
			online_pay.quantity=params.delete('quantity')
			online_pay.logistics_name=params.delete('logistics_name')
			online_pay.other_params=params.inspect
			online_pay.set_is_credit!()
			online_pay.remote_host=request.remote_host
			online_pay.remote_ip=request.remote_ip

			online_pay
		end

		def supplement_online_pay_credit_params!(online_pay,params)
			online_pay.credit_brand=params['brand']
			online_pay.credit_number=params['number']
			online_pay.credit_verification=params['verification_value']
			online_pay.credit_month=params['month']
			online_pay.credit_year=params['year']
			online_pay.credit_first_name=params['first_name']
			online_pay.credit_last_name=params['last_name']
		end
end