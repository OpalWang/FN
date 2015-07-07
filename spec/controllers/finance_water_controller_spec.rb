require 'rails_helper'
require "support/render_views"

describe FinanceWaterController do
	fixtures :users
	fixtures :finance_waters

	let!(:set_session) do
		request.session[:admin]="admin"
	end

	context "get show" do
		it "success" do
			get :show,:id=>users(:user_one),:page=>0
			expect(response.status).to eq 200
			expect(assigns(:finance_waters)).to eq FinanceWater.where(:user_id=>users(:user_one))
		end
	end

	context "get modify web" do
		it "failure html" do
			expect{
				post :modify_web,modify_web_params(999,"Sub","html")
			}.to change(FinanceWater,:count).by(0)
			expect(response.status).to eq 302
			expect(response.body).to redirect_to new_user_finance_water_path(users(:user_one))
			expect(flash[:notice].to_s).to match (/New amount must be greater than or equal to 0.0/)
		end

		it "success html" do
			expect{
				post :modify_web,modify_web_params(1,"Sub","html")
			}.to change(FinanceWater,:count).by(1)

			expect(response.status).to eq 302
			expect(response).to redirect_to show_user_finance_water_path(users(:user_one))
		end
	end

	context "get modify interface" do
		it "failure json" do
			oper=[
				{'symbol'=>"Add",'amount'=>"100",'reason'=>'score add 100','watertype'=>"score",'is_pay'=>'N','order_no'=>''},
				{'symbol'=>"Add",'amount'=>"50",'reason'=>'score add 50','watertype'=>"score",'is_pay'=>'N','order_no'=>''},
				{'symbol'=>"Sub",'amount'=>"999",'reason'=>'score sub 999','watertype'=>"score",'is_pay'=>'N','order_no'=>''},
			].to_json
			expect{
				post :modify,modify_interface_params(oper)
			}.to change(FinanceWater,:count).by(0)

			expect(response.status).to eq 200
			# p response.body
			expect(response.body).to match (/New amount must be greater than or equal to 0.0/)
		end

		it "failure for pay json" do
			oper=[
				{'symbol'=>"Add",'amount'=>"100",'reason'=>'score add 100','watertype'=>"score",'is_pay'=>'N','order_no'=>''},
				{'symbol'=>"Add",'amount'=>"50",'reason'=>'score add 50','watertype'=>"score",'is_pay'=>'Y','order_no'=>''},
				{'symbol'=>"Sub",'amount'=>"119",'reason'=>'score sub 119','watertype'=>"score",'is_pay'=>'Y','order_no'=>'test_score_001'},
				{'symbol'=>"Add",'amount'=>"19",'reason'=>'e_cash add 19','watertype'=>"e_cash",'is_pay'=>'N','order_no'=>''},
			].to_json
			expect{
				post :modify,modify_interface_params(oper)
			}.to change(FinanceWater,:count).by(0)

			expect(response.status).to eq 200
			# p response.body
			expect(response.body).to match (/支付交易订单号不可为空/)

			oper=[
				{'symbol'=>"Add",'amount'=>"100",'reason'=>'score add 100','watertype'=>"score",'is_pay'=>'N','order_no'=>''},
				{'symbol'=>"Add",'amount'=>"50",'reason'=>'score add 50','watertype'=>"score",'is_pay'=>'Y','order_no'=>'33'},
				{'symbol'=>"Sub",'amount'=>"119",'reason'=>'score sub 119','watertype'=>"score",'is_pay'=>'Y','order_no'=>'test_score_001'},
				{'symbol'=>"Add",'amount'=>"19",'reason'=>'e_cash add 19','watertype'=>"e_cash",'is_pay'=>'N','order_no'=>''},
			].to_json
			expect{
				post :modify,modify_interface_params(oper)
			}.to change(FinanceWater,:count).by(0)

			expect(response.status).to eq 200
			# p response.body
			expect(response.body).to match (/支付交易操作符只能为减/)
		end

		it "success json" do
			old_score=users(:user_one)['score']
			old_e_cash=users(:user_one)['e_cash']
			oper=[
				{'symbol'=>"Add",'amount'=>"100",'reason'=>'score add 100','watertype'=>"score",'is_pay'=>'N','order_no'=>''},
				{'symbol'=>"Add",'amount'=>"50",'reason'=>'score add 50','watertype'=>"score",'is_pay'=>'N','order_no'=>''},
				{'symbol'=>"Sub",'amount'=>"119",'reason'=>'score sub 119','watertype'=>"score",'is_pay'=>'N','order_no'=>''},
				{'symbol'=>"Add",'amount'=>"19",'reason'=>'e_cash add 19','watertype'=>"e_cash",'is_pay'=>'N','order_no'=>''},
			].to_json
			expect{
				post :modify,modify_interface_params(oper)
			}.to change(FinanceWater,:count).by(4)

			expect(response.status).to eq 200
			# p response.body
			expect(response.body).to match (/userid.*status.*reasons.*score.*e_cash.*waterno/)
			change_user=User.find(users(:user_one))
			expect(change_user.e_cash).to eq old_e_cash+19
			expect(change_user.score).to eq old_score+100+50-119
		end

		it "success and pay json" do
			OnlinePay.where("order_no like 'test%'").each do |op|
				ReconciliationDetail.where("online_pay_id=#{op.id}").delete_all
				op.delete
			end

			old_score=users(:user_one)['score']
			old_e_cash=users(:user_one)['e_cash']
			oper=[
				{'symbol'=>"Add",'amount'=>"100",'pay_amount'=>'0','currency'=>'','reason'=>'score add 100','watertype'=>"score",'is_pay'=>'N','order_no'=>''},
				{'symbol'=>"Add",'amount'=>"50",'pay_amount'=>'0','currency'=>'','reason'=>'score add 50','watertype'=>"score",'is_pay'=>'N','order_no'=>''},
				{'symbol'=>"Sub",'amount'=>"119",'pay_amount'=>'1.19','currency'=>'RMB','reason'=>'score sub 119','watertype'=>"score",'is_pay'=>'Y','order_no'=>'test_score_001'},
				{'symbol'=>"Add",'amount'=>"19",'pay_amount'=>'0','currency'=>'','reason'=>'e_cash add 19','watertype'=>"e_cash",'is_pay'=>'N','order_no'=>''},
				{'symbol'=>"Sub",'amount'=>"19",'pay_amount'=>'0.19','currency'=>'EUR','reason'=>'e_cash sub 19','watertype'=>"e_cash",'is_pay'=>'Y','order_no'=>'test_score_002'},
			].to_json
			expect{
				post :modify,modify_interface_params(oper)
			}.to change(OnlinePay,:count).by(2)

			expect(response.status).to eq 200
			# p response.body
			expect(response.body).to match (/userid.*status.*reasons.*score.*e_cash.*waterno/)
			reconciliation_detail=ReconciliationDetail.unscoped.last
			expect(reconciliation_detail.online_pay.order_no).to eq "test_score_002"
			expect(reconciliation_detail.amt.to_f).to eq 0.19
			expect(reconciliation_detail.reconciliation_flag).to eq "2"
		end
	end

	context "order refund" do
		it "failure call no order" do
			refund_params={
				'payway'=>'alipay',
				'paytype'=>'oversea',
				'order_no'=>'aaa',
				'datetime'=>Time.now,
				'amount'=>10.0
			}
			post :refund,refund_params
			expect(response.status).to eq 200
			expect(response.body).to match (/无此订单号/)
		end

		it "success call" do
			op=OnlinePay.last
			refund_params={
				'payway'=>op.payway,
				'paytype'=>op.paytype,
				'order_no'=>op.order_no,
				'parcel_no'=>'refunc_parcel_no',
				'datetime'=>Time.now,
				'amount'=>op.amount-0.01
			}
			post :refund,refund_params
			expect(response.status).to eq 200
			expect(response.body).to match (/success/)
		end
	end

	def modify_web_params(amount,symbol,format)
		{
			'system' => 'mypost4u',
			'channel'  => 'spec_fixtures',
			'userid'  => users(:user_one)['userid'],
			'symbol'  => symbol,
			'amount'  => amount,
			'operator'  => 'spec_script',
			'reason'  => 'test',
			'datetime'  => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
			'watertype' => 'score' ,
			'format' => format
		}
	end

	def modify_interface_params(oper)
		{
			'system' => 'mypost4u',
			'channel'  => 'spec_fixtures',
			'userid'  => users(:user_one)['userid'],
			'operator'  => 'spec_script',
			'datetime'  => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
			'oper'=>oper
		}
	end
end