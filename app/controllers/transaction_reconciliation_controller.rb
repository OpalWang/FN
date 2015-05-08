class TransactionReconciliationController < ApplicationController
	before_action :authenticate_admin!

	CONDITION_PARAMS=%w{payway paytype reconciliation_flag start_time end_time trade_no}
	def index
		@reconciliation_details=ReconciliationDetail.includes(:online_pay).all.page(params[:page])
	end

	def index_by_condition
		sql=sql_from_condition_filter(params)
		logger.info(sql)
		@reconciliation_details=ReconciliationDetail.find_by_sql( [sql,params] )
		@reconciliation_details=Kaminari.paginate_array(@reconciliation_details).page(params[:page]).per(ReconciliationDetail::PAGE_PER)

		render :index
	end

	private 
		def sql_from_condition_filter(params)
			sql="select * from reconciliation_details"
			index=1

			params.each do |k,v|
				next if v.blank? 
				next unless CONDITION_PARAMS.include?(k)
				
				if( k=="start_time")
					t_sql="timestamp>=:#{k}"
				elsif (k=="end_time")
					t_sql="timestamp<=:#{k}"
				else
					t_sql="#{k}=:#{k}"
				end

				if(index==1)
					sql="#{sql} where #{t_sql}"
				else
					sql="#{sql} and #{t_sql}"
				end

				index=index+1
			end

			sql="#{sql} order by payway,paytype asc,timestamp desc"
		end
end