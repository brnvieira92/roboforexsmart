#include <cassert>
#include <cmath>
#include <string>
#include <iostream>
#define MathFloor std::floor
#define MathCeil std::ceil
#define MathRound std::round
#define MathAbs std::abs
#define MathIsValidNumber std::isfinite
#include "../../mt5/Include/ForexSmartCore.mqh"
#include "../../mt5/Include/ForexSmartPlanMath.mqh"
using string=std::string;
constexpr int ORDER_TYPE_BUY=0,ORDER_TYPE_SELL=1,SYMBOL_TRADE_TICK_SIZE=0;
struct TechnicalPlan {string symbol="EURUSD#",currency="USD";bool buy=true;int exitPolicy=FULL_TECHNICAL_TARGET,targetSource=0;double entry=1.10012,tp=0,lot=.02,cashGoal=5,costsPerLot=2,obstacle=1.104,clearance=.0002,quoteBid=1.1,quoteAsk=1.10012,netGain=0,plannedTP=0;};
bool failProfit=false;
bool lastPlanSpaceRecheck=false;RecoverablePlanFailure lastPlanFailure=PLAN_FINAL;string rejection;
void Reject(string value){rejection=value;}
string DoubleToString(double value,int){return std::to_string(value);}
double SymbolInfoDouble(string symbol,int){return symbol=="USDJPY#"?.001:.00001;}
bool OrderCalcProfit(int side,string symbol,double lot,double entry,double exit,double &value){
 if(failProfit||entry<=0||exit<=0||lot<=0)return false;
 value=(side==ORDER_TYPE_BUY?1:-1)*(exit-entry)*100000*lot;
 // Nonlinear monotonic conversion deliberately tests the solver without assuming fixed pip value.
 if(symbol=="USDJPY#")value/=exit;
 return true;
}
#include "../../mt5/Include/ForexSmartCashTarget.mqh"
int main(){
 assert(CashRiskBudget(24.24,5,2)==2.5);
 assert(CashRiskBudget(1,5,2)==1);
 assert(CashRiskBudget(24,5,.5)==0);
 assert(CashRiskBudget(24,5,1.5)==5/1.5);
 TechnicalPlan p;
 assert(SolveFixedCashTarget(p));assert(std::abs(p.tp-1.10264)<1e-9);assert(std::abs(p.netGain-5)<1e-8);
 assert(p.tp<=p.obstacle-p.clearance+1e-9);
 p.entry=1.100125;assert(SolveFixedCashTarget(p));assert(p.netGain>=5-1e-8);
 p.entry=1.10012;p.lot=.03;assert(SolveFixedCashTarget(p));double tickCash=0;assert(CashTickAmount(p,tickCash));
 assert(p.netGain>=5-1e-8&&p.netGain<=5+tickCash+1e-8);
 double closerGross=0;OrderCalcProfit(ORDER_TYPE_BUY,p.symbol,p.lot,p.entry,p.tp-.00001,closerGross);
 assert(closerGross-p.costsPerLot*p.lot<5);
 p.buy=false;p.entry=1.1;p.obstacle=1.096;p.lot=.02;
 assert(SolveFixedCashTarget(p));assert(std::abs(p.tp-1.09748)<1e-9);
 assert(p.tp>=p.obstacle+p.quoteAsk-p.quoteBid+p.clearance-1e-9);
 p.entry=1.12136;p.quoteBid=1.12136;p.quoteAsk=1.12146;p.obstacle=1.12094;
 assert(!SolveFixedCashTarget(p));assert(lastPlanSpaceRecheck&&lastPlanFailure==PLAN_SPACE);
 p.symbol="USDJPY#";p.buy=true;p.entry=157.9;p.quoteBid=157.89;p.quoteAsk=157.9;p.obstacle=160;p.clearance=.02;p.lot=.02;p.costsPerLot=1.3;
 assert(SolveFixedCashTarget(p));assert(CashTickAmount(p,tickCash));assert(p.netGain>=5-1e-8&&p.netGain<=5+tickCash+1e-8);
 p.buy=false;p.entry=157.9;p.obstacle=155;assert(SolveFixedCashTarget(p));assert(p.tp>=p.obstacle+.03-1e-9);
 failProfit=true;assert(!SolveFixedCashTarget(p));failProfit=false;
 p.currency="BRL";assert(!SolveFixedCashTarget(p));
 assert(CashEstimateFits(5,5,.02));assert(!CashEstimateFits(4.90,5,.02));assert(!CashEstimateFits(5.10,5,.02));
 // Structural SL stays beyond validated wick with buffer, independent of cash TP.
 double sl=TechnicalStop(true,1.1,1.0999,1.1,1.099,.0002,0,.00002,.00001);
 assert(std::abs(sl-1.0988)<1e-9);
 double perLotLoss=(1.1-sl)*100000;
 double lot=CostedVolume(CashRiskBudget(24.24,5,2),perLotLoss,2,.01,100);
 assert(lot==.02);assert(lot*(perLotLoss+2)<=2.5);
 assert(CostedVolume(2.5,300,2,.01,100)==0); // broker .01 minimum would exceed the cap: reject.
 std::cout<<"Fixed cash target: passed\n";
}
