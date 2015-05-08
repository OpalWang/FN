class ReconciliationDetail < ActiveRecord::Base
	belongs_to :online_pay

	validates :payway, :transactionid, :transaction_status,:batch_id,:transaction_date, presence: true
	#validates :reconciliation_flag, inclusion: { in: %w{'0','1','2'},message: "%{value} is not a valid ReconciliationDetail.reconciliation_flag" }

	default_scope { order('payway,paytype asc,timestamp desc') }

	PAGE_PER=14
	paginates_per PAGE_PER

	RECONCILIATIONDETAIL_FLAG={
		'INIT' => '0',
		'FAIL' => '1',
		'SUCC' => '2'
	}

	RECONCILIATIONDETAIL_STATUS={
		'PAYPAL_Pending' => 'PEND',
		'PAYPAL_Processing' => 'PEND',
		'PAYPAL_Completed' => 'SUCC',
		'PAYPAL_Unclaimed' => 'SUCC',
		'PAYPAL_Denied' => 'FAIL',
		'PAYPAL_Reversed' => 'FAIL',
		'ALIPAY_TRANSACTION_succ' => 'SUCC',
		'ALIPAY_OVERSEA_P' => 'SUCC',
		'ALIPAY_OVERSEA_L' => 'SUCC',
		'ALIPAY_OVERSEA_W' => 'PEND',
		'ALIPAY_OVERSEA_F' => 'FAIL',
		'SOFORT_untraceable' => 'SUCC'
	}

	def self.init(init_params)
		find_params={}
		other_params={}

		init_params.each do |k,v|
			if k=="transactionid"|| k=="payway"|| k=="paytype"
				find_params[k]=v
			else
				other_params[k]=v
			end
		end
		#Rails.logger.info("find_params:#{find_params}")
		rd=ReconciliationDetail.find_or_initialize_by(find_params)
		rd.assign_attributes(other_params)
		#Rails.logger.info(rd.attributes)
		rd
		#exist_rd=ReconciliationDetail.find_by_payway_and_paytype_and_transactionid(init_params['payway'],init_params['paytype'],init_params['transactionid'])
	end

	def set_flag!(flag,desc="")
		self.reconciliation_flag=flag
		self.reconciliation_describe=desc
	end

	def valid_and_save!()
		set_params_by_transactionid!()

		if self.online_pay_id.blank?
			set_flag!(RECONCILIATIONDETAIL_FLAG['FAIL'],"get online_pay_failure:#{self.transactionid}")
		else
			set_flag_by_status_and_amount!()
		end

		save!()

		# exist_rd=ReconciliationDetail.find_by_payway_and_paytype_and_transactionid(self.payway,self.paytype,self.transactionid)
		# if exist_rd.blank?
		# 	save!()
		# else
		# 	Rails.logger.warn("#{self.transactionid} exist record and update status #{exist_rd.transaction_status} ==> #{self.transaction_status},flag #{exist_rd.reconciliation_flag} ==> #{self.reconciliation_flag}")
		# 	self.id=exist_rd.id
		# 	update_columns({})
		# end
		
	end

	def set_params_by_transactionid!()
		self.paytype='' if self.paytype.blank?
		self.feeamt=0.0 if self.feeamt.blank?
		self.feeamt=(-1)*self.feeamt if self.feeamt<0
		
		return nil if self.transactionid.blank? || self.payway.blank?
		self.online_pay=OnlinePay.find_by_payway_and_paytype_and_reconciliation_id(self.payway,self.paytype,self.transactionid)
		self.online_pay_status=self.online_pay.status unless self.online_pay.blank?
	end

	def set_flag_by_status_and_amount!()
		if self.paytype.blank?
			reconciliation_status=RECONCILIATIONDETAIL_STATUS["#{self.payway.upcase}_#{self.transaction_status}"]
		else
			reconciliation_status=RECONCILIATIONDETAIL_STATUS["#{self.payway.upcase}_#{self.paytype.upcase}_#{self.transaction_status}"]
		end

		if reconciliation_status.blank? || self.online_pay_status.blank?
			set_flag!(RECONCILIATIONDETAIL_FLAG['FAIL'],"set_flag_by_status get status failure:#{reconciliation_status} and #{self.transaction_status} - #{self.online_pay_status}")
		else
			if reconciliation_status=="SUCC" && self.online_pay_status =~ /^success/
				if self.online_pay.amount==self.amt
					set_flag!(RECONCILIATIONDETAIL_FLAG['SUCC'],"")
				else
					set_flag!(RECONCILIATIONDETAIL_FLAG['FAIL'],"amount not match: #{self.online_pay.amount} <=> #{self.amt}")
				end
			elsif (reconciliation_status!="SUCC" && !(self.online_pay_status =~ /^success/))
				set_flag!(RECONCILIATIONDETAIL_FLAG['SUCC'],"")
			elsif (reconciliation_status=="SUCC" && ! (self.online_pay_status =~ /^success/))
				set_flag!(RECONCILIATIONDETAIL_FLAG['FAIL'],"#{self.payway} is #{reconciliation_status} but online_pay is #{self.online_pay_status}")
			elsif (reconciliation_status!="SUCC" && self.online_pay_status =~ /^success/)
				set_flag!(RECONCILIATIONDETAIL_FLAG['FAIL'],"#{self.payway} is #{reconciliation_status} but online_pay is #{self.online_pay_status}")
			else
				set_flag!(RECONCILIATIONDETAIL_FLAG['FAIL'],"unknow? #{self.payway} is #{reconciliation_status} but online_pay is #{self.online_pay_status}")
			end
		end
	end


	def warn_to_file(errmsg="unknow")
		[self.payway,self.paytype,self.transactionid,self.timestamp,self.transaction_type,self.transaction_status,self.amt,self.online_pay_id,self.online_pay_status,self.reconciliation_flag,self.reconciliation_describe,errmsg].join(",")
	end

	 # def to_hash(errmsg="unknow")
		#  hash = {}; 
		#  self.attributes.each { |k,v| hash[k] = v }
		#  hash['errmsg']=errmsg

		#  hash
	 # end
end