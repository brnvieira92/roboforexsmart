#ifndef FOREX_SMART_CASH_TARGET
#define FOREX_SMART_CASH_TARGET
bool CashTickAmount(TechnicalPlan &p,double &amount){
 double pointSize=SymbolInfoDouble(p.symbol,SYMBOL_TRADE_TICK_SIZE),a=0,b=0;
 if(pointSize<=0||p.lot<=0||!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,p.symbol,p.lot,p.entry,p.tp,a)||!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,p.symbol,p.lot,p.entry,p.tp+(p.buy?pointSize:-pointSize),b))return false;
 amount=MathAbs(b-a);return MathIsValidNumber(amount)&&amount>0;
}
// Binary search on executable absolute tick indices. Uses broker profit conversion,
// not a hard-coded pip value (USDJPY/CHF and contract specifications can differ).
bool SolveFixedCashTarget(TechnicalPlan &p){
 double tickSize=SymbolInfoDouble(p.symbol,SYMBOL_TRADE_TICK_SIZE);
 if(p.currency!="USD"||p.cashGoal<=0||p.exitPolicy!=FULL_TECHNICAL_TARGET||p.targetSource!=0||tickSize<=0)return false;
 double edge=p.buy?TickDown(p.obstacle-p.clearance,tickSize):TickUp(p.obstacle+p.quoteAsk-p.quoteBid+p.clearance,tickSize);
 long base=(long)(p.buy?MathFloor(p.entry/tickSize+1e-8):MathCeil(p.entry/tickSize-1e-8));
 long edgeIndex=(long)MathRound(edge/tickSize),maximum=p.buy?edgeIndex-base:base-edgeIndex;
 double required=CashRequiredGross(p.cashGoal,p.lot,p.costsPerLot),gross=0;
 if(maximum<1||!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,p.symbol,p.lot,p.entry,edge,gross)||!MathIsValidNumber(gross))return false;
 if(gross+1e-8<required){lastPlanSpaceRecheck=true;lastPlanFailure=PLAN_SPACE;Reject("TP monetário ultrapassaria obstáculo | goal_net_USD="+DoubleToString(p.cashGoal,2)+" | maximum_net_USD="+DoubleToString(gross-p.costsPerLot*p.lot,4));return false;}
 long lo=0,hi=maximum;
 for(int j=0;j<64&&hi-lo>1;j++){
 long mid=lo+(hi-lo)/2;double priceValue=(double)(base+(p.buy?mid:-mid))*tickSize;
 if(!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,p.symbol,p.lot,p.entry,priceValue,gross)||!MathIsValidNumber(gross))return false;
 if(gross>=required)hi=mid;else lo=mid;
 }
 if(hi-lo>1)return false;
 p.tp=(double)(base+(p.buy?hi:-hi))*tickSize;
 if(!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,p.symbol,p.lot,p.entry,p.tp,gross))return false;
 p.netGain=gross-p.costsPerLot*p.lot;double tickCash=0;
 if(!CashTickAmount(p,tickCash)||p.netGain+1e-8<p.cashGoal||!CashEstimateFits(p.netGain,p.cashGoal,tickCash))return false;
 p.plannedTP=p.tp;return true;
}
#ifndef __cplusplus
bool EvaluateFixedCashPlan(TechnicalPlan &p,double maxLot=0,double maxBudget=0){
 if(p.currency!="USD"||p.cashGoal<=0||!MathIsValidNumber(p.minRR)||p.minRR<1||p.targetSource!=0){Reject("Alvo monetário requer conta USD, R:R >= 1 e obstáculo confirmado");return false;}
 p.budget=CashRiskBudget(RiskBudget(RelevantEquity(),RiskPercent),p.cashGoal,p.minRR);if(maxBudget>0)p.budget=MathMin(p.budget,maxBudget);
 if(!MathIsValidNumber(p.budget)||p.budget<=0){Reject("Orçamento monetário inválido");return false;}
 double tickSize=SymbolInfoDouble(p.symbol,SYMBOL_TRADE_TICK_SIZE);
 p.tp=p.buy?TickDown(p.obstacle-p.clearance,tickSize):TickUp(p.obstacle+p.quoteAsk-p.quoteBid+p.clearance,tickSize);
 if(!NewOrderPlan(p.symbol,p.buy,p.entry,p.sl,p.tp,p.lot,p.risk,p.budget))return false;
 if(maxLot>0){double originalLot=p.lot;p.lot=ExtensionVolumeLimit(maxLot,p.lot);p.risk*=p.lot/originalLot;}
 double loss=0,slip=0;
 if(!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,p.symbol,1,p.entry,p.sl,loss)||loss>=0||!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,p.symbol,1,p.entry,p.entry+(p.buy?-1:1)*SlippageReservePoints*SymbolInfoDouble(p.symbol,SYMBOL_POINT),slip)){Reject("Falha calculando risco do alvo monetário");return false;}
 p.costsPerLot=CommissionPerLotRoundTurn+MathAbs(slip)+PlanSwapReservePerLot;p.risk=(MathAbs(loss)+p.costsPerLot)*p.lot;p.rawLot=p.budget/(MathAbs(loss)+p.costsPerLot);
 if(!SolveFixedCashTarget(p))return false;
 // Final validation with the actual solved TP, rather than the temporary obstacle edge.
 double checkedLot=0,checkedRisk=0;
 if(!NewOrderPlan(p.symbol,p.buy,p.entry,p.sl,p.tp,checkedLot,checkedRisk,p.budget))return false;
 if(maxLot>0){double oldLot=checkedLot;checkedLot=ExtensionVolumeLimit(maxLot,checkedLot);checkedRisk*=checkedLot/oldLot;}
 if(MathAbs(checkedLot-p.lot)>1e-8||checkedRisk>p.budget+1e-8){Reject("Lote/risco mudou durante cálculo do TP monetário; nenhuma ordem enviada");return false;}
 p.risk=checkedRisk;p.rr=p.risk>0?p.netGain/p.risk:0;
 if(p.rr+1e-9<p.minRR){Reject("Alvo monetário não cobre R:R mínimo | RR_net="+DoubleToString(p.rr,4));return false;}
 Journal("cash_target",PlanSummary(p)+" | exit=full_position_no_partial_no_trailing | risk_budget_capped_by_goal=1 | rounding=nearest_tick_at_or_above_goal | realized_result_not_guaranteed=1");
 return true;
}
#endif
#endif
