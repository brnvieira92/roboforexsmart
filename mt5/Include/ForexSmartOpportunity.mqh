#ifndef FOREX_SMART_OPPORTUNITY
#define FOREX_SMART_OPPORTUNITY
// One intent per configured symbol. No persistence/rearming of waiting signals on restart.
struct MarketOpportunity {
 bool active;bool buy;OpportunityState state;int evaluations;int breakCloses;
 datetime originBar;datetime evaluatedBar;datetime breakoutBar;datetime sampled;
 string parent;string strategy;string identity;long generation;
 double zone;double barrier;double invalidationSL;double atrValue;
};
MarketOpportunity opportunities[];
string IntentDispatchKey(string parent){return StateKey("i."+StringFormat("%I64X",TextFingerprint(parent)));}
bool AlreadyIntentDispatched(string parent){return GlobalVariableCheck(IntentDispatchKey(parent));}
void ResetOpportunities(){ArrayResize(opportunities,0);intentParent="";intentModule="";}
void EnsureOpportunities(){int old=ArraySize(opportunities),n=ArraySize(symbols);ArrayResize(opportunities,n);for(int j=old;j<n;j++)ZeroMemory(opportunities[j]);}
bool OpportunityActive(int i){return i>=0&&i<ArraySize(opportunities)&&opportunities[i].active;}
void OpportunityTransition(int i,OpportunityState state,string reason){
 if(!OpportunityActive(i))return;
 opportunities[i].state=state;
 Journal("opportunity_state","opportunity="+opportunities[i].parent+" | strategy="+opportunities[i].strategy+" | symbol="+symbols[i]+" | state="+EnumToString(state)+" | reason="+reason+" | signal_tf="+EnumToString(SignalTimeframe())+" | wait_bars="+(string)ConfiguredWaitBars(symbols[i])+" | evaluations="+(string)opportunities[i].evaluations);
 if(state==INVALIDATED||state==EXPIRED||state==SUBMITTED||state==FILLED)opportunities[i].active=false;
}
bool TrendModuleContext(int i,bool buy){
 string s=symbols[i];ResearchConfig cfg=Config(s);
 if(!cfg.enabled||!ResearchSession()||!NewsClear(s))return false;
 double h=Value(research[i].h50,1),longEMA=Value(research[i].h200,1),adx=Value(research[i].adx,1),a=SignalATRValue(i,1),base=SignalATRValue(i,10);
 if(h==EMPTY_VALUE||longEMA==EMPTY_VALUE||adx==EMPTY_VALUE||a==EMPTY_VALUE||base==EMPTY_VALUE||a<=0||base<=0||adx<cfg.adx)return false;
 MarketRegime regime=DetectRegime(h,longEMA,adx,a/base,false);lastRegime=EnumToString(regime);
 if(regime!=TREND_UP&&regime!=TREND_DOWN&&regime!=BREAKOUT)return false;
 return buy?h>longEMA:h<longEMA;
}
void ScheduleOpportunity(int i,bool buy,datetime bar,TechnicalPlan &p){
 if(!PlanUseEventWaits||StrategyMode!=MULTISTRATEGY||EntryPlanner!=TECHNICAL_PLAN||!EntrySession()||intentParent!="")return;
 // CHF_R01 already implements range reversal. Never convert a rejected trend to a range trade.
 if(StrategyID(symbols[i])=="CHF_R01"||lastPlanFailure==PLAN_FINAL||p.atrValue<=0||p.entry<=0)return;
 OpportunityState state=WAIT_PULLBACK;
 if((lastPlanFailure==PLAN_SPACE||lastPlanFailure==PLAN_NO_LEVEL)&&PlanEnableBreakRetest&&p.obstacle>0)state=WAIT_BREAKOUT;
 else if(!PlanEnableTrendPullback)return;
 double zone=Value(research[i].m20,1);if(zone==EMPTY_VALUE||zone<=0)return;
 EnsureOpportunities();if(OpportunityActive(i))return;
 ZeroMemory(opportunities[i]);opportunities[i].active=true;opportunities[i].buy=buy;
 opportunities[i].originBar=bar;opportunities[i].evaluatedBar=bar;opportunities[i].parent=p.id;
 opportunities[i].strategy=lastStrategy;opportunities[i].identity=Identity();opportunities[i].generation=authorizationGeneration;
 opportunities[i].zone=zone;opportunities[i].barrier=p.obstacle;opportunities[i].invalidationSL=p.sl;opportunities[i].atrValue=p.atrValue;
 if(p.sl<=0){
 MqlRates closed[];ArraySetAsSeries(closed,true);if(CopyRates(symbols[i],SignalTimeframe(),1,2,closed)!=2){opportunities[i].active=false;return;}
 PlanSettings settings=PlanConfig(symbols[i]);double buffer=MathMax(settings.bufferPips*PipSize(SymbolInfoDouble(symbols[i],SYMBOL_POINT),(int)SymbolInfoInteger(symbols[i],SYMBOL_DIGITS)),p.quoteAsk-p.quoteBid);
 opportunities[i].invalidationSL=buy?MathMin(closed[0].low,closed[1].low)-buffer:MathMax(closed[0].high,closed[1].high)+buffer+p.quoteAsk-p.quoteBid;
 }
 OpportunityTransition(i,state,"recoverable geometry; frozen zone="+DoubleToString(zone,8)+" | barrier="+DoubleToString(p.obstacle,8)+" | thesis_invalidation="+DoubleToString(opportunities[i].invalidationSL,8)+" | confirmed_pivot_missing="+(string)(int)(p.sl<=0));
}
void ScheduleSpreadWait(int i,bool buy,datetime bar,double signalClose){
 if(!PlanUseEventWaits||EntryPlanner!=TECHNICAL_PLAN||!EntrySession()||intentParent!="")return;
 int direction=0;double close=0,stop=0,target=0;
 if(!ReadSignalForEntry(i,direction,close,stop,target)||direction!=(buy?1:-1)||stop<=0)return;
 EnsureOpportunities();if(OpportunityActive(i))return;
 ZeroMemory(opportunities[i]);opportunities[i].active=true;opportunities[i].buy=buy;
 opportunities[i].originBar=bar;opportunities[i].evaluatedBar=bar;opportunities[i].parent=symbols[i]+"/"+lastStrategy+"/"+(string)(long)bar;
 opportunities[i].strategy=lastStrategy;opportunities[i].identity=Identity();opportunities[i].generation=authorizationGeneration;
 opportunities[i].invalidationSL=signalClose+(buy?-stop:stop);
 OpportunityTransition(i,WAIT_SPREAD,"only evaluate when absolute spread returns inside limit; original candle only");
}
bool PendingIntentStillValid(int i,bool retrying){
 if(intentParent!=""){
 if(!OpportunityActive(i))return false;
 MarketOpportunity o=opportunities[i];PlanSettings cfg=PlanConfig(symbols[i]);MqlTick q;
 if(o.identity!=Identity()||o.generation!=authorizationGeneration||OpportunityExpired(iBarShift(symbols[i],SignalTimeframe(),o.originBar,true),cfg.waitBars)||!EntrySession()||!SymbolInfoTick(symbols[i],q)||(o.buy?q.bid<=o.invalidationSL:q.ask>=o.invalidationSL)){
 OpportunityTransition(i,INVALIDATED,"original thesis/session/deadline changed during planning");return false;}
 }
 if(retrying){
 if(i>=ArraySize(spaceRechecks)||!spaceRechecks[i].active||spaceRechecks[i].identity!=Identity()||spaceRechecks[i].generation!=authorizationGeneration||TimeTradeServer()-spaceRechecks[i].born>=PlanRecheckLifetimeSeconds)return false;
 MqlTick q;if(!SymbolInfoTick(symbols[i],q)||(spaceRechecks[i].buy?q.bid<=spaceRechecks[i].invalidationSL:q.ask>=spaceRechecks[i].invalidationSL))return false;
 }
 return true;
}
// Reprice the SAME protective SL/TP, re-evaluate the full monetary plan, and bound work.
// New ticks are normal; equality of tick timestamps or spreads is not a signal invariant.
bool RefreshPlanForSend(int i,datetime bar,TechnicalPlan &p,double intentEntry=0){
 string s=p.symbol;double point=SymbolInfoDouble(s,SYMBOL_POINT),pip=PipSize(point,(int)SymbolInfoInteger(s,SYMBOL_DIGITS)),tickSize=SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE);
 double originalEntry=intentEntry>0?intentEntry:p.entry,originalBudget=p.budget;int limit=MaxSpreadPoints;
 if(StrategyMode==MULTISTRATEGY){ResearchConfig cfg=Config(s);limit=MathMin(limit,cfg.spread);}
 for(int pass=0;pass<PlanSendRefreshAttempts;pass++){
 if(iTime(s,SignalTimeframe(),0)!=bar){Reject("Envio: candle do sinal mudou | expected="+(string)(long)bar+" | actual="+(string)(long)iTime(s,SignalTimeframe(),0));return false;}
 int direction=0;double close=0,stop=0,target=0;
 bool signalValid=intentModule!=""?TrendModuleContext(i,p.buy):(ReadSignalForEntry(i,direction,close,stop,target)&&direction==(p.buy?1:-1)&&lastStrategy==p.strategy);
 if(!signalValid){Reject("Envio: sinal/contexto deixou de ser válido");return false;}
 // ReadSignal updates diagnostics; keep the actual alternative module identity.
 lastStrategy=p.strategy;
 MqlTick q;if(!SymbolInfoTick(s,q)){Reject("Envio: cotação indisponível");return false;}
 double entry=p.buy?q.ask:q.bid,age=(double)(TimeTradeServer()-q.time);
 if(!QuoteWithinSendPolicy(originalEntry,entry,q.bid,q.ask,age,PlanSendMaxQuoteAgeSeconds,pip,PlanSendMaxDriftPips,point,limit)){
 Reject("Envio: cotação fora da política | age_s="+DoubleToString(age,1)+" | drift_pips="+DoubleToString(MathAbs(entry-originalEntry)/pip,2)+" | max_drift_pips="+DoubleToString(PlanSendMaxDriftPips,2)+" | spread_pts="+DoubleToString((q.ask-q.bid)/point,1)+" | max_spread_pts="+(string)limit);return false;}
 if(MathAbs(q.bid-p.signalClose)>PlanMaxEntryDriftATR*p.atrValue){Reject("Envio: entrada atrasada além da distância ATR do sinal");return false;}
 p.entry=entry;p.requested=entry;p.quoteBid=q.bid;p.quoteAsk=q.ask;p.initialR=MathAbs(entry-p.sl);
 PlanSettings cfg=PlanConfig(s);double cap=StopDistanceCap((int)PlanStopLimitPolicy,cfg.maxStop,p.atrValue,cfg.maxStopATR,pip,PlanAbnormalStopPips);
 if(p.initialR>cap+tickSize*1e-6||p.initialR<=0||(p.targetSource==0&&p.targetMode!=FIXED_NET_USD&&!TargetFits(p.buy,p.entry,p.sl,p.tp,p.obstacle,q.ask-q.bid,p.clearance,tickSize))){Reject("Envio: geometria técnica invalidada | "+PlanSummary(p));return false;}
 if(!EvaluateTechnicalEconomics(p,0,originalBudget))return false;
 if(p.minRR<1||p.netGain<=0||!MathIsValidNumber(p.rr)||p.rr+1e-9<p.minRR){Reject("Envio: R:R líquido insuficiente após atualizar preço | "+PlanSummary(p));return false;}
 MqlTick after;if(!SymbolInfoTick(s,after))return false;
 // A small quote move is covered by the slippage reserve already charged to risk and gain.
 // Larger changes get a bounded reprice, never a fresh market order or widened SL.
 double move=MathAbs((p.buy?after.ask:after.bid)-p.entry);
 if(move<=SlippageReservePoints*point+tickSize*1e-6&&after.ask-after.bid<=q.ask-q.bid+SlippageReservePoints*point+tickSize*1e-6&&TimeTradeServer()-after.time<=PlanSendMaxQuoteAgeSeconds){
 p.created=TimeTradeServer();Journal("plan_revalidated",PlanSummary(p)+" | refresh_pass="+(string)(pass+1)+" | old_entry="+DoubleToString(originalEntry,8)+" | final_quote_delta_pts="+DoubleToString(move/point,2)+" | protective_SL_unchanged=1 | cash_TP_repriced_before_dispatch="+(string)(int)(p.targetMode==FIXED_NET_USD));return EntrySession();}
 Journal("send_reprice","plan="+p.id+" | pass="+(string)(pass+1)+" | delta_pts="+DoubleToString(move/point,2));
 }
 Reject("Envio: mercado mudou durante revalidação econômica; limite de atualizações atingido sem ordem");return false;
}
bool FinalDispatchGuard(TechnicalPlan &p,datetime bar,bool report=true){
 MqlTick q;string s=p.symbol;double point=SymbolInfoDouble(s,SYMBOL_POINT),pip=PipSize(point,(int)SymbolInfoInteger(s,SYMBOL_DIGITS));
 int limit=MaxSpreadPoints;if(StrategyMode==MULTISTRATEGY){ResearchConfig cfg=Config(s);limit=MathMin(limit,cfg.spread);}
 if(iTime(s,SignalTimeframe(),0)!=bar||!SymbolInfoTick(s,q)){if(report)Reject("Envio final: candle mudou ou cotação indisponível após persistência");return false;}
 double currentEntry=p.buy?q.ask:q.bid;double delta=MathAbs(currentEntry-p.entry);
 if(!QuoteWithinSendPolicy(p.entry,currentEntry,q.bid,q.ask,(double)(TimeTradeServer()-q.time),PlanSendMaxQuoteAgeSeconds,pip,PlanSendMaxDriftPips,point,limit)||delta>SlippageReservePoints*point+1e-12){
 if(report)Reject("Envio final: preço excedeu reserva após persistência | plan_entry="+DoubleToString(p.entry,8)+" | current="+DoubleToString(currentEntry,8)+" | delta_pts="+DoubleToString(delta/point,2)+" | reserve_pts="+(string)SlippageReservePoints+" | age_s="+(string)(long)(TimeTradeServer()-q.time));return false;}
 double minimum=(SymbolInfoInteger(s,SYMBOL_TRADE_STOPS_LEVEL)+2)*point;
 if(p.buy?(p.sl>=q.bid-minimum||p.tp<=q.ask+minimum):(p.sl<=q.ask+minimum||p.tp>=q.bid-minimum)){
 if(report)Reject("Envio final: proteção não executável | bid="+DoubleToString(q.bid,8)+" | ask="+DoubleToString(q.ask,8)+" | SL="+DoubleToString(p.sl,8)+" | TP="+DoubleToString(p.tp,8)+" | broker_min="+DoubleToString(minimum,8));return false;}
 double ratio=(q.ask-q.bid)/MathAbs(currentEntry-p.sl);
 if(ratio>MaxSpreadStopRatio){if(report)Reject("Envio final: spread/SL="+DoubleToString(ratio,4)+" | maximum="+DoubleToString(MaxSpreadStopRatio,4));return false;}
 if(LossLimit()){if(report)Reject("Envio final: limite diário atingido");return false;}
 if(PositionsTotal()+OrdersTotal()>=2||PositionSelect(s)){if(report)Reject("Envio final: limite/posição existente | positions="+(string)PositionsTotal()+" | orders="+(string)OrdersTotal());return false;}
 if(!ExposureAllowed(s,p.buy?1:-1)){if(report)Reject("Envio final: exposição USD correlacionada");return false;}
 TechnicalPlan checked;checked=p;checked.entry=currentEntry;checked.initialR=MathAbs(currentEntry-p.sl);
 PlanSettings stopSettings=PlanConfig(s);double currentCap=StopDistanceCap((int)PlanStopLimitPolicy,stopSettings.maxStop,p.atrValue,stopSettings.maxStopATR,pip,PlanAbnormalStopPips);
 if(checked.initialR>currentCap+1e-12){if(report)Reject("Envio final: distância SL="+DoubleToString(checked.initialR/pip,4)+" | maximum_pips="+DoubleToString(currentCap/pip,4));return false;}
 double loss=0,spreadCash=0;
 if(!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,s,1,currentEntry,p.sl,loss)||loss>=0||!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,s,1,currentEntry,currentEntry+(p.buy?-1:1)*(q.ask-q.bid),spreadCash)){
 if(report)Reject("Envio final: falha ao calcular economia atual");return false;}
 checked.risk=(MathAbs(loss)+p.costsPerLot)*p.lot;
 if(!ProjectPlanReward(checked,checked.netGain)){if(report)Reject("Envio final: projeção da saída indisponível");return false;}
 if(p.targetMode==FIXED_NET_USD){double tickCash=0;if(!CashTickAmount(checked,tickCash)||!CashEstimateFits(checked.netGain,p.cashGoal,tickCash)){if(report)Reject("Envio final: alvo monetário mudou após cotação | projected_net="+DoubleToString(checked.netGain,4)+" | goal="+DoubleToString(p.cashGoal,2));return false;}}
 double currentRR=checked.risk>0?checked.netGain/checked.risk:0,budget=MathMin(p.budget,RiskBudget(RelevantEquity(),RiskPercent));
 if(!MathIsValidNumber(currentRR)||checked.risk>budget+1e-8||currentRR+1e-9<p.minRR){
 if(report)Reject("Envio final: economia mudou | risk="+DoubleToString(checked.risk,4)+" | budget="+DoubleToString(budget,4)+" | RR_net="+DoubleToString(currentRR,4)+" | min_RR="+DoubleToString(p.minRR,4));return false;}
 double costRatio=(p.costsPerLot+MathAbs(spreadCash))/MathAbs(loss),costLimit=MaxCostRiskRatio;
 if(StrategyMode==MULTISTRATEGY){ResearchConfig cfg=Config(s);costLimit=MathMin(costLimit,cfg.maxCost);}
 if(costRatio>costLimit){if(report)Reject("Envio final: custo/risco="+DoubleToString(costRatio,4)+" | maximum="+DoubleToString(costLimit,4));return false;}
 double margin=0,free=AccountInfoDouble(ACCOUNT_MARGIN_FREE),aggregate=AggregateRisk(),aggregateBudget=RiskBudget(RelevantEquity(),MaxAggregateRiskPercent);
 if(!OrderCalcMargin(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,s,p.lot,currentEntry,margin)||margin>free*0.9){
 if(report)Reject("Envio final: margem="+DoubleToString(margin,4)+" | free_with_reserve="+DoubleToString(free*0.9,4));return false;}
 if(aggregate+checked.risk>aggregateBudget){if(report)Reject("Envio final: risco agregado="+DoubleToString(aggregate+checked.risk,4)+" | maximum="+DoubleToString(aggregateBudget,4));return false;}

 return true;
}
void ProcessOpportunities(){
 EnsureOpportunities();
 for(int i=0;i<ArraySize(opportunities);i++){
 if(!OpportunityActive(i))continue;
 MarketOpportunity o=opportunities[i];string s=symbols[i];datetime bar=iTime(s,SignalTimeframe(),0);PlanSettings cfg=PlanConfig(s);
 int elapsed=iBarShift(s,SignalTimeframe(),o.originBar,true);
 if(o.identity!=Identity()||o.generation!=authorizationGeneration||!PlanUseEventWaits||!EntrySession()||EntryPlanner!=TECHNICAL_PLAN){OpportunityTransition(i,INVALIDATED,"account/authorization/permissions/config changed");continue;}
 if(OpportunityExpired(elapsed,cfg.waitBars)){OpportunityTransition(i,EXPIRED,"candle deadline reached");continue;}
 MqlTick q;if(!SymbolInfoTick(s,q)||TimeTradeServer()-q.time>PlanSendMaxQuoteAgeSeconds)continue;
 if(o.buy?q.bid<=o.invalidationSL:q.ask>=o.invalidationSL){OpportunityTransition(i,INVALIDATED,"original thesis SL crossed");continue;}
 if(AlreadyIntentDispatched(o.parent)||AlreadyDispatched(s,o.originBar)||AlreadyDispatched(s,bar)||PositionSelect(s)||OrdersTotal()+PositionsTotal()>=2){OpportunityTransition(i,INVALIDATED,"dispatch/position/exposure arbitration");continue;}
 int limit=MaxSpreadPoints;if(StrategyMode==MULTISTRATEGY){ResearchConfig rc=Config(s);limit=MathMin(limit,rc.spread);}
 if((q.ask-q.bid)/SymbolInfoDouble(s,SYMBOL_POINT)>limit)continue;
 int direction=0;double close=0,stop=0,target=0;string module="";
 if(o.state==WAIT_SPREAD){
 if(bar!=o.originBar){OpportunityTransition(i,EXPIRED,"spread wait cannot outlive original signal candle");continue;}
 if(!ReadSignalForEntry(i,direction,close,stop,target)||direction!=(o.buy?1:-1)||lastStrategy!=o.strategy){OpportunityTransition(i,INVALIDATED,"original signal/filter invalid");continue;}
 }else{
 if(bar==o.evaluatedBar)continue;
 if(!TrendModuleContext(i,o.buy)){OpportunityTransition(i,INVALIDATED,"trend/regime/calendar/session invalid");continue;}
 MqlRates r[];ArraySetAsSeries(r,true);if(CopyRates(s,SignalTimeframe(),1,3,r)!=3||r[0].time+SignalSeconds()!=bar)continue;
 opportunities[i].evaluatedBar=bar;
 if(!ConsecutiveSignalBars((long)o.evaluatedBar,(long)bar,SignalSeconds())){opportunities[i].breakCloses=0;o.breakCloses=0;}
 double tolerance=MathMax(o.atrValue*PlanBreakBufferATR,q.ask-q.bid);
 if(o.state==WAIT_PULLBACK&&!PlanEnableTrendPullback){OpportunityTransition(i,INVALIDATED,"pullback module disabled");continue;}
 if((o.state==WAIT_BREAKOUT||o.state==WAIT_RETEST)&&!PlanEnableBreakRetest){OpportunityTransition(i,INVALIDATED,"break/retest module disabled");continue;}
 if(r[0].time<o.originBar||(o.state==WAIT_PULLBACK&&r[1].time<o.originBar)||(o.state==WAIT_RETEST&&r[0].time<=o.breakoutBar))continue;
 int consecutive=o.breakCloses;
 int event=ClosedWaitEvent((int)o.state,o.buy,o.zone,o.barrier,o.atrValue*PlanPullbackZoneATR,tolerance,PlanBreakConfirmCloses,consecutive,r[1].low,r[1].high,r[0].open,r[0].close,r[0].low,r[0].high);
 opportunities[i].breakCloses=consecutive;
 if(event==0)continue;
 if(event==1){opportunities[i].breakoutBar=r[0].time;OpportunityTransition(i,WAIT_RETEST,"consecutive closed candles beyond frozen obstacle");continue;}
 if(event==3){OpportunityTransition(i,INVALIDATED,"confirmed breakout failed");continue;}
 module=o.state==WAIT_PULLBACK?"TREND_PULLBACK":"BREAK_RETEST";
 ResearchConfig economics=Config(s);close=r[0].close;stop=SignalATRValue(i,1)*economics.stopATR;target=stop*economics.reward;
 string prefix=StringFind(s,"USDJPY")==0?"JPY":StringFind(s,"USDCHF")==0?"CHF":StringSubstr(s,0,3);
 lastStrategy=TempoStrategyID(prefix+(module=="TREND_PULLBACK"?"_P01":"_BR01"));
 }
 if(opportunities[i].evaluations>=2){OpportunityTransition(i,EXPIRED,"maximum two economic evaluations after confirmation");continue;}
 opportunities[i].evaluations++;
 intentParent=o.parent;intentModule=module;
 Journal("opportunity_alternative","opportunity="+o.parent+" | strategy="+lastStrategy+" | symbol="+s+" | module="+(module==""?"SPREAD_RECOVERY":module)+" | signal_bar="+(string)(long)bar);
 Journal("opportunity_trigger","opportunity="+o.parent+" | strategy="+lastStrategy+" | symbol="+s+" | financial_approval_pending=1");
 AttemptSignalEntry(i,o.buy,bar,close,stop,target,false);
 intentParent="";intentModule="";
 // Every confirmation receives one construction/send pipeline; no blind timed repeats.
 OpportunityTransition(i,lastEntryOutcome==3?FILLED:lastEntryOutcome==2?SUBMITTED:INVALIDATED,"alternative evaluated; see plan decision");
 }
}
#endif
