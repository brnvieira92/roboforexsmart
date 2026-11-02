#ifndef FOREX_SMART_COUNTERFACTUAL
#define FOREX_SMART_COUNTERFACTUAL
// Diagnostic hypothesis ONLY: immediate quoted entry + fixed SL/TP + fixed horizon.
// It does not simulate fills, portfolio arbitration, partials or trailing; never counts as a trade.
struct RejectedObservation {bool active;TechnicalPlan plan;datetime signalBar;datetime observedBar;int bars;};
RejectedObservation rejectedObservations[];
void ResetCounterfactuals(){ArrayResize(rejectedObservations,0);}
void TrackRejectedPlan(TechnicalPlan &p){
 if(!PlanCollectCounterfactual||p.id==""||p.lot<=0||p.risk<=0||p.sl<=0||p.tp<=0||SignedTargetDistance(p.buy,p.entry,p.tp)<=0)return;
 for(int j=0;j<ArraySize(rejectedObservations);j++)if(rejectedObservations[j].plan.id==p.id)return;
 int index=-1;for(int j=0;j<ArraySize(rejectedObservations);j++)if(!rejectedObservations[j].active){index=j;break;}
 if(index<0){index=ArraySize(rejectedObservations);if(index>=64){Journal("counterfactual_skipped","plan="+p.id+" | bounded_capacity=64");return;}ArrayResize(rejectedObservations,index+1);}
 ZeroMemory(rejectedObservations[index]);rejectedObservations[index].active=true;rejectedObservations[index].plan=p;
 rejectedObservations[index].signalBar=iTime(p.symbol,PERIOD_M5,0);
 Journal("counterfactual_start","plan="+p.id+" | strategy="+p.strategy+" | symbol="+p.symbol+" | horizon_M5_bars="+(string)PlanCounterfactualHorizonBars+" | rule=FIXED_SL_TP_STOP_FIRST | execution_assumed=1 | not_executed_exit_policy=1 | not_portfolio_backtest=1");
}
void EndCounterfactual(int index,string outcome,double exitPrice,bool measurable){
 TechnicalPlan p=rejectedObservations[index].plan;double gross=0;
 bool calculated=measurable&&OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,p.symbol,p.lot,p.entry,exitPrice,gross);
 Journal("counterfactual_result","plan="+p.id+" | strategy="+p.strategy+" | symbol="+p.symbol+" | outcome="+outcome+" | observed_bars="+(string)rejectedObservations[index].bars+" | hypothetical_exit="+DoubleToString(exitPrice,8)+" | hypothetical_net_R="+(calculated?DoubleToString((gross-p.costsPerLot*p.lot)/p.risk,6):"N/A")+" | currency_conversion_at_observation=1 | fixed_target_hypothesis_not_actual_partial_trailing=1 | not_evidence_of_missed_profit=1");
 rejectedObservations[index].active=false;
}
void ProcessCounterfactuals(){
 if(!PlanCollectCounterfactual)return;
 for(int i=0;i<ArraySize(rejectedObservations);i++){
 if(!rejectedObservations[i].active)continue;
 TechnicalPlan p=rejectedObservations[i].plan;
 MqlRates r[];ArraySetAsSeries(r,false);datetime start=rejectedObservations[i].observedBar>0?rejectedObservations[i].observedBar+300:rejectedObservations[i].signalBar;
 datetime end=iTime(p.symbol,PERIOD_M5,0)-1;if(end<start)continue;
 int copied=CopyRates(p.symbol,PERIOD_M5,start,end,r);if(copied<=0)continue;
 for(int j=0;j<copied&&rejectedObservations[i].active;j++){
 if(r[j].time!=start+(datetime)(j*300)){EndCounterfactual(i,"INCOMPLETE_CANDLE_PATH",0,false);break;}
 rejectedObservations[i].observedBar=r[j].time;rejectedObservations[i].bars++;
 // Bid candles: sell exits need Ask. Freeze observed spread; cannot infer historical spread path.
 double spread=p.quoteAsk-p.quoteBid,lo=r[j].low+(p.buy?0:spread),hi=r[j].high+(p.buy?0:spread);
 int outcome=CounterfactualBarDecision(p.buy,r[j].time==rejectedObservations[i].signalBar,lo,hi,p.sl,p.tp,rejectedObservations[i].bars>=PlanCounterfactualHorizonBars);
 if(outcome==CF_ENTRY_AMBIGUOUS){EndCounterfactual(i,"AMBIGUOUS_ENTRY_CANDLE",0,false);break;}
 if(outcome==CF_STOP||outcome==CF_BOTH_STOP_FIRST){EndCounterfactual(i,outcome==CF_BOTH_STOP_FIRST?"BOTH_TOUCHED_STOP_FIRST":"STOP_TOUCHED",p.sl,true);break;}
 if(outcome==CF_TARGET){EndCounterfactual(i,"TARGET_TOUCHED_ASSUMED_SPREAD",p.tp,true);break;}
 if(outcome==CF_HORIZON){EndCounterfactual(i,"HORIZON_MARK_ASSUMED_SPREAD",r[j].close+(p.buy?0:spread),true);break;}

 }
 }
}
#endif
