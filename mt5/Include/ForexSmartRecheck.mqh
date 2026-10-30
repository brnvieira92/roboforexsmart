#ifndef FOREX_SMART_RECHECK
#define FOREX_SMART_RECHECK
struct SpaceRecheck {
 bool active;bool buy;int attempts;datetime born;datetime checked;datetime bar;
 string identity;long generation;string strategy;double invalidationSL;
};
SpaceRecheck spaceRechecks[];
void EnsureSpaceRechecks(){int old=ArraySize(spaceRechecks),n=ArraySize(symbols);ArrayResize(spaceRechecks,n);for(int j=old;j<n;j++)ZeroMemory(spaceRechecks[j]);}
void ResetSpaceRechecks(){ArrayResize(spaceRechecks,0);}
void CancelSpaceRecheck(int i,string reason){
 if(i<0||i>=ArraySize(spaceRechecks)||!spaceRechecks[i].active)return;
 spaceRechecks[i].active=false;
 Journal("recheck_cancel","symbol="+symbols[i]+" | signal_bar="+(string)(long)spaceRechecks[i].bar+" | attempts="+(string)spaceRechecks[i].attempts+" | reason="+reason);
}
void ScheduleSpaceRecheck(int i,bool buy,datetime bar,double invalidationSL){
 if(!PlanEnableSpaceRecheck||EntryPlanner!=TECHNICAL_PLAN||!lastPlanSpaceRecheck||!EntrySession()||invalidationSL<=0)return;
 EnsureSpaceRechecks();spaceRechecks[i].active=true;spaceRechecks[i].buy=buy;spaceRechecks[i].attempts=0;
 spaceRechecks[i].born=TimeTradeServer();spaceRechecks[i].checked=TimeTradeServer();spaceRechecks[i].bar=bar;
 spaceRechecks[i].identity=Identity();spaceRechecks[i].generation=authorizationGeneration;spaceRechecks[i].strategy=lastStrategy;spaceRechecks[i].invalidationSL=invalidationSL;
 Journal("recheck_scheduled","symbol="+symbols[i]+" | strategy="+lastStrategy+" | bar="+(string)(long)bar+" | interval_seconds="+(string)PlanRecheckIntervalSeconds+" | lifetime_seconds="+(string)PlanRecheckLifetimeSeconds+" | max_additional_checks="+(string)PlanRecheckMaxAttempts+" | no_order_submitted=1");
}
bool ReadSignalForEntry(int i,int &direction,double &signalClose,double &stop,double &target){
 double f=Value(fastHandles[i],1),slo=Value(slowHandles[i],1),a=Value(atrHandles[i],1);
 if(f==EMPTY_VALUE||slo==EMPTY_VALUE||a==EMPTY_VALUE||a<=0)return false;
 MqlRates rates[];ArraySetAsSeries(rates,true);if(CopyRates(symbols[i],PERIOD_M5,1,3,rates)!=3)return false;
 lastStrategy="LEGACY";lastRegime="LEGACY";signalClose=rates[0].close;
 direction=LegacyDirection(f,slo,rates[1].close,rates[0].close);
 stop=LegacyStop(a);target=LegacyTarget(a,SymbolInfoDouble(symbols[i],SYMBOL_POINT),f,slo,MinTPPoints,MaxTPPoints);
 if(StrategyMode==MULTISTRATEGY)direction=ResearchSignal(i,a,stop,target);
 return true;
}
string DispatchKey(string s){return StateKey("e."+StringFormat("%I64X",TextFingerprint(s)));}
bool AlreadyDispatched(string s,datetime bar){return GlobalVariableCheck(DispatchKey(s))&&GlobalVariableGet(DispatchKey(s))==(double)bar;}
void ProcessSpaceRechecks(){
 EnsureSpaceRechecks();
 for(int i=0;i<ArraySize(spaceRechecks);i++){
 if(!spaceRechecks[i].active)continue;
 bool sameAccount=spaceRechecks[i].identity==Identity();bool sameSession=spaceRechecks[i].generation==authorizationGeneration;
 bool sameBar=iTime(symbols[i],PERIOD_M5,0)==spaceRechecks[i].bar;
 int decision=RetryDecision(sameAccount,sameSession,EntrySession()&&PlanEnableSpaceRecheck&&EntryPlanner==TECHNICAL_PLAN,sameBar,true,AlreadyDispatched(symbols[i],spaceRechecks[i].bar),spaceRechecks[i].attempts,PlanRecheckMaxAttempts,(long)(TimeTradeServer()-spaceRechecks[i].born),(long)(TimeTradeServer()-spaceRechecks[i].checked),PlanRecheckIntervalSeconds,PlanRecheckLifetimeSeconds);
 if(decision==0){CancelSpaceRecheck(i,"account/session/permissions/bar/expiry/limit/dispatch changed");continue;}
 if(decision==1)continue;
 int direction=0;double close=0,stop=0,target=0;
 if(!ReadSignalForEntry(i,direction,close,stop,target)||direction!=(spaceRechecks[i].buy?1:-1)||lastStrategy!=spaceRechecks[i].strategy){CancelSpaceRecheck(i,"original signal or filters no longer valid");continue;}
 MqlTick tick;
 if(!SymbolInfoTick(symbols[i],tick)||TimeCurrent()-tick.time>30||(spaceRechecks[i].buy?tick.bid<=spaceRechecks[i].invalidationSL:tick.ask>=spaceRechecks[i].invalidationSL)){CancelSpaceRecheck(i,"stale quote or original technical invalidation reached");continue;}
 spaceRechecks[i].attempts++;spaceRechecks[i].checked=TimeTradeServer();
 Journal("recheck_attempt","symbol="+symbols[i]+" | bar="+(string)(long)spaceRechecks[i].bar+" | additional_check="+(string)spaceRechecks[i].attempts+" | rebuild_full_plan=1");
 AttemptSignalEntry(i,spaceRechecks[i].buy,spaceRechecks[i].bar,close,stop,target,true);
 if(spaceRechecks[i].active&&(!lastPlanSpaceRecheck||spaceRechecks[i].attempts>=PlanRecheckMaxAttempts))CancelSpaceRecheck(i,lastPlanSpaceRecheck?"additional check limit reached":"different rejection or no further retry allowed");
 }
 activePlanID="";
}
#endif
