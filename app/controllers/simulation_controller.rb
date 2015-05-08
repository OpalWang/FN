class SimulationController < ApplicationController
	protect_from_forgery :except => [:simulate_post]
	CALL_HOST=Settings.simulation.call_host

	@@simulation_num=0

	def index
	end

	def index_reconciliation
	end

	def simulate_reconciliation
		payment_system=params['payment_system']
		callpath="#{CALL_HOST}/pay/#{payment_system}/get_reconciliation"

		response=method_url_call("get",callpath,"false",{}) 

		render :text=>"#{response.body}"
	end

	def simulate_finance_modify
		userid=params['userid']
		score=params['score'].to_f
		symbol=params['symbol']
		watertype=params['watertype']

		callpath="#{CALL_HOST}/finance_water/#{userid}/modify"
		score_params=score_params(userid,score,symbol,watertype)

		response=method_url_call("post",callpath,"false",score_params) 

		render :text=>"#{response.body}"
	end

	def simulate_registe
		userid=params['userid']
		score=params['score'].to_f
		e_cash=params['e_cash'].to_f

		callpath="#{CALL_HOST}/registe"
		registe_params=registe_params(userid,score,e_cash)
		logger.info("#{registe_params.inspect}")
		response=method_url_call("post",callpath,"false",registe_params) 

		render :text=>"#{response.body}"				
	end

	def simulate_pay
		payway=params['payway']
		logger.info("payway:#{payway}")

		userid="552b461202d0f099ec000033"
		callpath="/pay/#{userid}/submit"
		
		simulate_order_no=create_pay_order_no(payway)

		uri = URI.parse("#{CALL_HOST}#{callpath}")
		logger.info("path:#{callpath}")
		http = Net::HTTP.new(uri.host, uri.port)

		case payway
		when 'paypal' then simulate_params=init_paypal_submit_params(simulate_order_no) 
		when 'sofort' then simulate_params=init_sofort_submit_params(simulate_order_no) 
		when 'alipay_oversea' then simulate_params=init_alipay_oversea_submit_params(simulate_order_no) 
		when 'alipay_transaction' then simulate_params=init_alipay_transaction_submit_params(simulate_order_no)
		else
			simulate_params={}
		end

		logger.info("simulate_params:#{simulate_params.inspect}")

		request = Net::HTTP::Post.new(uri.request_uri) 
		request.set_form_data(simulate_params)
		logger.info("call!!")
		response=http.request(request)
		res_result=JSON.parse(response.body)
		logger.info("body:#{response.body}\nresult:#{res_result}")
		unless (res_result['redirect_url'].blank?)
			redirect_to CGI.unescape(res_result['redirect_url'])
		else
			flash[:notice]='please modify and try again!'
			render :action=>'index'
		end
	end

	def simulate_pay_credit
		trade_no=params['trade_no']
		userid="552b461202d0f099ec000033"
		callpath="/pay/#{userid}/submit_creditcard"

		uri = URI.parse("#{CALL_HOST}#{callpath}")
		logger.info("path:#{callpath}")
		http = Net::HTTP.new(uri.host, uri.port)

		request = Net::HTTP::Post.new(uri.request_uri) 
		request.set_form_data(credit_params(trade_no))
		logger.info("call!!")
		response=http.request(request)
		res_result=JSON.parse(response.body)
		logger.info("body:#{response.body}\nresult:#{res_result}")
		unless (res_result['redirect_url'].blank?)
			redirect_to CGI.unescape(res_result['redirect_url'])
		else
			render :text=>"code:#{response.code}</br>body:#{response.body}</br>result:#{res_result}"
		end
	end

	def callback_return
		@params=params

		# @params.each do |k,v|
		# 	logger.info("#{k} = #{v}")
		# end
	end

	def callback_notify
		@params=params

		@params.each do |k,v|
			logger.info("#{k} = #{v}")
		end

		render :text=>'success'
	end

	def simulate_get
		call_url=params['call_url']
		# response=method_url_call("get",call_url,"false")

		# logger.info("SIMULATE_GET:#{response.code}:#{response.body}")
		# render :text=>"#{response.code}:#{response.body}"
		redirect_to call_url
	end

	def simulate_post
		call_url=params['call_url']
		method_url_call("post",call_url,"false") and return
		# response=method_url_call("post",call_url,"false")

		# logger.info("SIMULATE_POST:#{response.code}:#{response.body}")
		# render :text=>"#{response.code}:#{response.body}"
	end

	private
		def method_url_call(method,url_path,https,params={})
			uri = URI.parse(url_path)

			http = Net::HTTP.new(uri.host, uri.port)
			http.use_ssl =  uri.scheme == 'https' if https==true

			if(method=="get")
				request = Net::HTTP::Get.new(uri.request_uri) 
			else
				request = Net::HTTP::Post.new(uri.request_uri) 
				if(params.blank?)
					request.set_form_data(method_params(method))
				else
					request.set_form_data(params)
				end
			end
			response=http.request(request)

			response	
		end
	
		def method_params(method)
			{
				"notify_id"=>"4e5606af1c34d98e86228566c18954262a",
				 "notify_type"=>"trade_status_sync", 
				 "sign"=>"046894a5ef53ee6ea294b13332456dae",
				  "trade_no"=>"2015040900001000050051921095", 
				  "total_fee"=>"195.63", 
				  "out_trade_no"=>"mypost4u_alipay_oversea_20150429_001", 
				  "currency"=>"EUR", 
				  "notify_time"=> current_time_ymdHMS(), 
				  "trade_status"=>"WAIT_SELLER_SEND_GOODS", 
				  "sign_type"=>"MD5"
			}
		end

		def credit_params(trade_no)
			{
				'payway'=>'paypal',
				'paytype'=>'',
				'trade_no'=>trade_no,
				'amount'=>10.0,
				'currency'=>'EUR',
				'ip'=>'10.2.2.2',
				'brand' => 'visia', 
				'number' => '1111111111',
				'verification_value' => '315',
				'month' => '12',
				'year' => '15',
				'first_name' => 'ly',
				'last_name' => 'xxx'	
			}
		end

		def score_params(userid,score,sybmol,watertype)
			{
				'system'=>'mypost4u',
				'channel'=>'web',
				'userid'=>userid,
				'operator'=>'system',
				'datetime'=>current_time_ymdHMS(),
				'type'=>'score',
				'symbol'=>sybmol,
				'amount'=>score,
				'reason'=>'test',
				'watertype'=>watertype
			}
		end

		def registe_params(userid,score,e_cash)
			{
				'system'=>'mypost4u',
				'channel'=>'web',
				'userid'=>userid,
				'username'=>'testname',
				'email'=>'testname@126.com',
				'accountInitAmount'=>e_cash,
				'scoreInitAmount'=>score,
				'operator'=>'system',
				'datetime'=>current_time_ymdHMS()
			}
		end

		def create_pay_order_no(payway)
			@@simulation_num=@@simulation_num+1
			callnum=sprintf("%03d",@@simulation_num)
			calldate=current_time_ymdHMS("%Y%m%d")

			case payway
			when 'paypal' then order_no="paypal_#{calldate}_#{callnum}"
			when 'sofort' then order_no="sofort#{calldate}#{callnum}" 
			when 'alipay_oversea' then order_no="alipay_oversea_#{calldate}_#{callnum}"
			when 'alipay_transaction' then order_no="alipay_transaction_#{calldate}_#{callnum}"
			else
				order_no="nopayway_#{calldate}_#{callnum}"
			end

			order_no
		end

		def init_online_pay_params
			{
				'system'=>'',
				'payway'=>'',
				'paytype'=>'',
				'userid'=>'',
				'amount'=>'',
				'currency'=>'',
				'order_no'=>'',
				'success_url'=>'',
				'notification_url'=>'',
				'notification_email'=>'',
				'abort_url'=>'',
				'timeout_url'=>'',
				'ip'=>'',
				'description'=>'',
				'country'=>'',
				'quantity'=>'',
				'logistics_name'=>''
			}
		end

		def init_paypal_submit_params(order_no)
			paypal_submit_params={
				'system'=>'mypost4u',
				'payway'=>'paypal',
				'paytype'=>'',
				'amount'=>50,
				'currency'=>'EUR',
				'order_no'=>"#{order_no}",
				'description'=>'send iphone',
				'ip'=>'127.0.0.1',
				'success_url'=>'http://127.0.0.1:3001/simulation/callback_return',
				'abort_url'=>'http://127.0.0.1:3001/simulation/callback_return',
				'country'=>'de',
				'channel'=>'web'
			}

			init_online_pay_params.merge!(paypal_submit_params)
		end

		def init_sofort_submit_params(order_no)
			sofort_submit_params={
				'system'=>'mypost4u',
				'payway'=>'sofort',
				'paytype'=>'',
				'amount'=>50,
				'currency'=>'EUR',
				'order_no'=>"#{order_no}",
				'success_url'=>'http://127.0.0.1:3001/simulation/callback_return',
				'abort_url'=>'http://127.0.0.1:3001/simulation/callback_return',
				'notification_url'=>'http://127.0.0.1:3001/simulation/callback_notify',
				'timeout_url'=>'http://127.0.0.1:3001/simulation/callback_return',
				'country'=>'de',
				'channel'=>'web'
			}		
			init_online_pay_params.merge!(sofort_submit_params)
		end

		def init_alipay_oversea_submit_params(order_no)
			alipay_oversea_submit_params={
				'system'=>'mypost4u',
				'payway'=>'alipay',
				'paytype'=>'oversea',
				'amount'=>50,
				'currency'=>'EUR',
				'order_no'=>"#{order_no}",
				'description'=>'send iphone',
				'success_url'=>'http://127.0.0.1:3001/simulation/callback_return',
				'notification_url'=>'http://127.0.0.1:3001/simulation/callback_notify',
				'channel'=>'web'
			}		
			init_online_pay_params.merge!(alipay_oversea_submit_params)
		end

		def init_alipay_transaction_submit_params(order_no)
			alipay_transaction_submit_params={
				'system'=>'mypost4u',
				'payway'=>'alipay',
				'paytype'=>'transaction',
				'amount'=>144.0,
				'order_no'=>"#{order_no}",
				'logistics_name'=>'logistics_name',
				'description'=>'订单号TIME000000011的寄送包裹费用',
				'success_url'=>'http://127.0.0.1:3001/simulation/callback_return',
				'notification_url'=>'http://127.0.0.1:3001/simulation/callback_notify',
				'quantity'=>1,
				'channel'=>'web'
			}		
			init_online_pay_params.merge!(alipay_transaction_submit_params)
		end

		def current_time_ymdHMS(format="")
			if (format.blank?)
				Time.now.strftime("%Y-%m-%d %H:%M:%S")
			else
				Time.now.strftime(format)
			end
		end
end
