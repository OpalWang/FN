class OnlinePay < ActiveRecord::Base
	ONLINE_PAY_STATUS_ENUM=%w{submit failure_submit  submit_credit   success_notify  cancel_notify  failure_notify success_credit  failure_credit}

	belongs_to :user
	has_one :reconciliation_detail
	validates :system, :channel, :userid, :payway,:amount,:order_no,:status, presence: true
	validates :amount, numericality:{:greater_than_or_equal_to=>0.00}
	validates :status, inclusion: { in: ONLINE_PAY_STATUS_ENUM,message: "%{value} is not a valid online_pay.status" }


	ALIPAY_OVERSEA_CALLBACK_STATUS={
		'TRADE_CLOSED' => -1,
		'TRADE_FINISHED' => 9
	}

	ALIPAY_TRANSACTION_CALLBACK_STATUS={
		'TRADE_CLOSED' => -1,
 		'WAIT_BUYER_PAY' => 0,
		'WAIT_SELLER_SEND_GOODS' => 1,
		'WAIT_BUYER_CONFIRM_GOODS' => 2,
		'TRADE_FINISHED' => 9
	}

	SOFORT_CALLBACK_STATUS={
 		'loss' => 0,
		'pending' => 1,
		'refunded' => 2,
		'received' => 9,
		'untraceable' => 9,
		'cancel_notify'=>9
	}

	#paypal.callback_status=paypal.stauts
	PAYPAL_CALLBACK_STATUS={
		'submit_credit'=>0,
 		'cancel_notify'=>9
	}

	def set_is_credit!()
		if(self.system=='paypal')
			self.is_credit=true
		else
			self.is_credit=false
		end
	end

	# def set_credit_info_by_params!(params)
	# 	self.credit_brand=params['brand']
	# 	self.credit_number=params['number']
	# 	self.credit_verification=params['verification_value']
	# 	self.credit_month=params['month']
	# 	self.credit_year=params['year']
	# 	self.credit_first_name=params['first_name']
	# 	self.credit_last_name=params['last_name']
	# end

	def set_status!(status,reason)
		self.status=status
		self.reason=reason
	end

	def set_status_by_callback!()
		self.reason=''
		if(self.payway=="alipay" && self.paytype=="oversea")
			# TRADE_FINISHED 交易结束、买家已付款
			# TRADE_CLOSED 交易关闭、买家没有付款
			if(self.callback_status=="TRADE_FINISHED")
				self.status="success_notify"
			elsif(self.callback_status=="TRADE_CLOSED")
				self.status="cancel_notify"
			else
				self.status="intermediate_notify"
			end
		elsif(self.payway=="alipay" && self.paytype=="transaction")
			# WAIT_BUYER_PAY 等待买家付款
			# WAIT_SELLER_SEND_GOODS 买家已付款,等待卖家发货
			# WAIT_BUYER_CONFIRM_GOODS 卖家已发货,等待买家确认
			# TRADE_FINISHED 交易成功结束
			# TRADE_CLOSED 交易中途关闭(已结束,未成功完成)

			# 担 保 交 易 的 交 易 状 态 变 更 顺 序 依 次 是 : WAIT_BUYER_PAY →
			# WAIT_SELLER_SEND_GOODS → WAIT_BUYER_CONFIRM_GOODS →
			# TRADE_FINISHED。
			# 即 时 到 账 的 交 易 状 态 变 更 顺 序 依 次 是 : WAIT_BUYER_PAY →
			# TRADE_FINISHED。
			if(self.callback_status=="TRADE_FINISHED")
				self.status="success_notify"
			elsif(self.callback_status=="TRADE_CLOSED")
				self.status="cancel_notify"
			else
				self.status="intermediate_notify"
			end			
		elsif(self.payway=="paypal")
		elsif(self.payway=="sofort")
			if(self.callback_status=="received")
				self.status="success_notify"
			elsif(self.callback_status=="untraceable")
				self.status="success_notify"
			else
				self.status="intermediate_notify"
			end				
		end
	end

	def check_has_updated?(new_callback_status)
		has_updated=false

		if (new_callback_status.blank?)
			has_updated=true
		elsif !self.callback_status.blank?
			if(self.payway=="alipay" && self.paytype=="oversea")
				# TRADE_FINISHED 交易结束、买家已付款
				# TRADE_CLOSED 交易关闭、买家没有付款
				if(ALIPAY_OVERSEA_CALLBACK_STATUS[self.callback_status]==9)
					has_updated=true
				elsif(ALIPAY_OVERSEA_CALLBACK_STATUS[self.callback_status]>=ALIPAY_OVERSEA_CALLBACK_STATUS[new_callback_status])
					has_updated=true
				end	
			elsif(self.payway=="alipay" && self.paytype=="transaction")
				# WAIT_BUYER_PAY 等待买家付款
				# WAIT_SELLER_SEND_GOODS 买家已付款,等待卖家发货
				# WAIT_BUYER_CONFIRM_GOODS 卖家已发货,等待买家确认
				# TRADE_FINISHED 交易成功结束
				# TRADE_CLOSED 交易中途关闭(已结束,未成功完成)

				# 担 保 交 易 的 交 易 状 态 变 更 顺 序 依 次 是 : WAIT_BUYER_PAY →
				# WAIT_SELLER_SEND_GOODS → WAIT_BUYER_CONFIRM_GOODS →
				# TRADE_FINISHED。
				# 即 时 到 账 的 交 易 状 态 变 更 顺 序 依 次 是 : WAIT_BUYER_PAY →
				# TRADE_FINISHED。

				if(ALIPAY_TRANSACTION_CALLBACK_STATUS[self.callback_status]==9)
					has_updated=true
				elsif(ALIPAY_TRANSACTION_CALLBACK_STATUS[self.callback_status]>=ALIPAY_TRANSACTION_CALLBACK_STATUS[new_callback_status])
					has_updated=true
				end			
			elsif(self.payway=="paypal")
			elsif(self.payway=="sofort")
				if(SOFORT_CALLBACK_STATUS[self.callback_status]==9)
					has_updated=true
				elsif(SOFORT_CALLBACK_STATUS[self.callback_status]>=SOFORT_CALLBACK_STATUS[new_callback_status])
					has_updated=true
				end		
			end	
		end

		if(has_updated)
			Rails.logger.info("the call has updated record:#{self.callback_status} >= #{new_callback_status} ")
		end
		has_updated
	end

	#return pay_detail instance
	def self.get_instance_pay_detail(online_pay)
		logger.info ("#{online_pay.payway.camelize}#{online_pay.paytype.camelize}Detail.new(online_pay)")
		eval("#{online_pay.payway.camelize}#{online_pay.paytype.camelize}Detail.new(online_pay)")
	end

	# status => is use status condition   it's  array []
	# is_credit => is credit use
	# is_lock => is use lock row
	def self.get_online_pay_instance(payway,paytype,params,status=[],is_credit=false,is_lock=true)
		if paytype.blank?
			pay_combine=payway
		else
			pay_combine=payway+"_"+paytype
		end
		
		begin
			trade_no=''
			if is_credit==true 	#spec  credit submit
				trade_no=params['trade_no']
			else
				case pay_combine
				when 'alipay_oversea' then trade_no=params['out_trade_no']
				when 'alipay_transaction' then trade_no=params['out_trade_no']
				when 'paypal' then trade_no=params['token']
				when 'sofort' then trade_no=params["status_notification"]["transaction"]
				else
					logger.warn("ONLINE_PAY CALLBACK:get_online_pay_instance:#{pay_combine}=#{payway}+#{paytype}!")
				end
			end

			if trade_no.blank?
				raise "no trade_no get from params! #{pay_combine}=#{payway}+#{paytype}!"
			end

			#use lock !!
			#OnlinePay.lock.find_by_payway_and_paytype_and_trade_no_and_status(payway,paytype,trade_no,'submit')
			if status.blank?
				if is_lock==true
					OnlinePay.lock.find_by_payway_and_paytype_and_trade_no(payway,paytype,trade_no)
				else
					OnlinePay.find_by_payway_and_paytype_and_trade_no(payway,paytype,trade_no)
				end
			else
				if is_lock==true
					OnlinePay.lock.find_by_payway_and_paytype_and_trade_no_and_status(payway,paytype,trade_no,status)
				else
					OnlinePay.find_by_payway_and_paytype_and_trade_no_and_status(payway,paytype,trade_no,status)
				end
			end
		rescue=>e
			logger.warn("get_online_pay_instance failure:#{e.message}")
			nil
		end
	end
end