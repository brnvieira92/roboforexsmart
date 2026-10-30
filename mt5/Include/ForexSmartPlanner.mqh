#ifndef FOREX_SMART_PLANNER
#define FOREX_SMART_PLANNER
struct TechnicalPlan {
 int version;string id;string symbol;string strategy;string regime;string currency;bool buy;int timeframe;datetime created;datetime structureTime;datetime obstacleTime;
 double managedSL;double quoteBid;double quoteAsk;double requested;double entry;double sl;double tp;double initialR;double atrValue;double atrMultiplier;double buffer;double structure;double obstacle;double clearance;
 double minRR;double rawLot;double lot;double budget;double risk;double netGain;double costsPerLot;double rr;double trailR;double partialR;double mfe;double mae;
 int lookback;int pivotLeft;int pivotRight;int maxAge;int exitPolicy;int trailPolicy;ulong order;bool audited;bool breached;double signalClose;double plannedSL;double plannedTP;
};
bool lastPlanSpaceRecheck=false;
struct PlanSettings {ENUM_TIMEFRAMES tf;double multiplier;double bufferPips;double maxStop;double trailR;};
PlanSettings PlanConfig(string s){PlanSettings c;c.tf=PlanEURTimeframe;c.multiplier=PlanEURATR;c.bufferPips=PlanEURBufferPips;c.maxStop=PlanEURMaxStopPips;c.trailR=PlanEURTrailR;
 if(StringFind(s,"USDJPY")==0){c.tf=PlanJPYTimeframe;c.multiplier=PlanJPYATR;c.bufferPips=PlanJPYBufferPips;c.maxStop=PlanJPYMaxStopPips;c.trailR=PlanJPYTrailR;}
 if(StringFind(s,"USDCHF")==0){c.tf=PlanCHFTimeframe;c.multiplier=PlanCHFATR;c.bufferPips=PlanCHFBufferPips;c.maxStop=PlanCHFMaxStopPips;c.trailR=PlanCHFTrailR;}
 if(StringFind(s,"GBPUSD")==0){c.tf=PlanGBPTimeframe;c.multiplier=PlanGBPATR;c.bufferPips=PlanGBPBufferPips;c.maxStop=PlanGBPMaxStopPips;c.trailR=PlanGBPTrailR;}return c;
}
bool PlanSettingsValid(){
 if(PlanObstacleMinTouches<2||PlanObstacleMinSpanBars<1||PlanObstacleTouchSeparation<1||PlanObstacleTolerancePips<=0||PlanObstacleBreakCloses<2||PlanObstacleM15Lookback<10||PlanObstacleM15Lookback>250||PlanRecheckIntervalSeconds<2||PlanRecheckLifetimeSeconds<=PlanRecheckIntervalSeconds||PlanRecheckLifetimeSeconds>120||PlanRecheckMaxAttempts<1||PlanRecheckMaxAttempts>5)return false;
 if(PlanSnapshotMaxFiles<1||PlanSnapshotMaxFiles>1000||(PlanAllowTargetExtension&&(PlanExtendedTargetMaxR<PlanMaxTargetR||PlanExtendedTargetMaxR>10)))return false;
 if(PlanHistoryBars<200||PlanHistoryBars>2000||PlanStructureLookback<5||PlanStructureLookback+PlanPivotLeft+1>PlanHistoryBars||PlanPivotLeft<1||PlanPivotRight<1||PlanMaxStructureAge<PlanPivotRight||PlanMaxStructureAge>PlanStructureLookback||PlanMinStopPips<0||PlanBufferATR<0||PlanBufferSpread<0||PlanMaxTargetR<=0||PlanMaxEntryDriftATR<=0||PlanSwapReservePerLot<0||PlanPartialR<1)return false;
 string pairs[4]={"EURUSD","USDJPY","USDCHF","GBPUSD"};
 for(int i=0;i<4;i++){PlanSettings c=PlanConfig(pairs[i]);if((c.tf!=PERIOD_M5&&c.tf!=PERIOD_M15)||c.multiplier<=0||c.bufferPips<0||c.maxStop<=0||c.maxStop<PlanMinStopPips||c.trailR<1)return false;}return true;
}
string PendingPlanPath(string s){return "FSPlan-"+accountScope+"-pending-"+StringFormat("%I64X",TextFingerprint(s))+".csv";}
string PositionPlanPath(ulong id){return "FSPlan-"+accountScope+"-"+(string)id+".csv";}
bool PlanRow(int f,string key,string value){return FileWrite(f,key,value)>0;}
bool SaveTechnicalPlan(string path,TechnicalPlan &p){
 string temp=path+".tmp";int f=FileOpen(temp,FILE_WRITE|FILE_CSV|FILE_ANSI,';',CP_UTF8);if(f==INVALID_HANDLE)return false;
 bool ok=true;
 ok=PlanRow(f,"version",(string)p.version)&&ok;ok=PlanRow(f,"id",p.id)&&ok;ok=PlanRow(f,"symbol",p.symbol)&&ok;ok=PlanRow(f,"strategy",p.strategy)&&ok;ok=PlanRow(f,"regime",p.regime)&&ok;ok=PlanRow(f,"currency",p.currency)&&ok;ok=PlanRow(f,"buy",(string)(int)p.buy)&&ok;
 ok=PlanRow(f,"timeframe",(string)p.timeframe)&&ok;ok=PlanRow(f,"created",(string)(long)p.created)&&ok;ok=PlanRow(f,"structureTime",(string)(long)p.structureTime)&&ok;ok=PlanRow(f,"obstacleTime",(string)(long)p.obstacleTime)&&ok;
 ok=PlanRow(f,"order",(string)p.order)&&ok;ok=PlanRow(f,"audited",(string)(int)p.audited)&&ok;ok=PlanRow(f,"breached",(string)(int)p.breached)&&ok;
 ok=PlanRow(f,"lookback",(string)p.lookback)&&ok;ok=PlanRow(f,"pivotLeft",(string)p.pivotLeft)&&ok;ok=PlanRow(f,"pivotRight",(string)p.pivotRight)&&ok;ok=PlanRow(f,"maxAge",(string)p.maxAge)&&ok;
 ok=PlanRow(f,"exitPolicy",(string)p.exitPolicy)&&ok;ok=PlanRow(f,"trailPolicy",(string)p.trailPolicy)&&ok;
 ok=PlanRow(f,"managedSL",DoubleToString(p.managedSL,12))&&ok;
 ok=PlanRow(f,"quoteBid",DoubleToString(p.quoteBid,12))&&ok;ok=PlanRow(f,"quoteAsk",DoubleToString(p.quoteAsk,12))&&ok;
 ok=PlanRow(f,"requested",DoubleToString(p.requested,12))&&ok;ok=PlanRow(f,"entry",DoubleToString(p.entry,12))&&ok;ok=PlanRow(f,"sl",DoubleToString(p.sl,12))&&ok;ok=PlanRow(f,"tp",DoubleToString(p.tp,12))&&ok;
 ok=PlanRow(f,"initialR",DoubleToString(p.initialR,12))&&ok;ok=PlanRow(f,"atrValue",DoubleToString(p.atrValue,12))&&ok;ok=PlanRow(f,"atrMultiplier",DoubleToString(p.atrMultiplier,8))&&ok;ok=PlanRow(f,"buffer",DoubleToString(p.buffer,12))&&ok;
 ok=PlanRow(f,"structure",DoubleToString(p.structure,12))&&ok;ok=PlanRow(f,"obstacle",DoubleToString(p.obstacle,12))&&ok;ok=PlanRow(f,"clearance",DoubleToString(p.clearance,12))&&ok;
 ok=PlanRow(f,"minRR",DoubleToString(p.minRR,8))&&ok;ok=PlanRow(f,"rawLot",DoubleToString(p.rawLot,12))&&ok;ok=PlanRow(f,"lot",DoubleToString(p.lot,8))&&ok;ok=PlanRow(f,"budget",DoubleToString(p.budget,8))&&ok;
 ok=PlanRow(f,"risk",DoubleToString(p.risk,8))&&ok;ok=PlanRow(f,"netGain",DoubleToString(p.netGain,8))&&ok;ok=PlanRow(f,"costsPerLot",DoubleToString(p.costsPerLot,8))&&ok;ok=PlanRow(f,"rr",DoubleToString(p.rr,8))&&ok;
 ok=PlanRow(f,"trailR",DoubleToString(p.trailR,8))&&ok;ok=PlanRow(f,"partialR",DoubleToString(p.partialR,8))&&ok;ok=PlanRow(f,"mfe",DoubleToString(p.mfe,12))&&ok;ok=PlanRow(f,"mae",DoubleToString(p.mae,12))&&ok;
 ok=PlanRow(f,"signalClose",DoubleToString(p.signalClose,12))&&ok;ok=PlanRow(f,"plannedSL",DoubleToString(p.plannedSL,12))&&ok;ok=PlanRow(f,"plannedTP",DoubleToString(p.plannedTP,12))&&ok;
 FileFlush(f);FileClose(f);if(!ok){FileDelete(temp);return false;}return FileMove(temp,0,path,FILE_REWRITE);
}
bool LoadTechnicalPlan(string path,TechnicalPlan &p){
 ZeroMemory(p);int f=FileOpen(path,FILE_READ|FILE_CSV|FILE_ANSI,';',CP_UTF8);if(f==INVALID_HANDLE)return false;
 while(!FileIsEnding(f)){string k=FileReadString(f),v=FileReadString(f);double d=StringToDouble(v);
 if(k=="version")p.version=(int)StringToInteger(v);else if(k=="id")p.id=v;else if(k=="symbol")p.symbol=v;else if(k=="strategy")p.strategy=v;else if(k=="regime")p.regime=v;else if(k=="currency")p.currency=v;else if(k=="buy")p.buy=StringToInteger(v)!=0;
 else if(k=="timeframe")p.timeframe=(int)StringToInteger(v);else if(k=="created")p.created=(datetime)StringToInteger(v);else if(k=="structureTime")p.structureTime=(datetime)StringToInteger(v);else if(k=="obstacleTime")p.obstacleTime=(datetime)StringToInteger(v);
 else if(k=="order")p.order=(ulong)StringToInteger(v);else if(k=="audited")p.audited=StringToInteger(v)!=0;else if(k=="breached")p.breached=StringToInteger(v)!=0;
 else if(k=="lookback")p.lookback=(int)StringToInteger(v);else if(k=="pivotLeft")p.pivotLeft=(int)StringToInteger(v);else if(k=="pivotRight")p.pivotRight=(int)StringToInteger(v);else if(k=="maxAge")p.maxAge=(int)StringToInteger(v);
 else if(k=="exitPolicy")p.exitPolicy=(int)StringToInteger(v);else if(k=="trailPolicy")p.trailPolicy=(int)StringToInteger(v);
 else if(k=="managedSL")p.managedSL=d;
 else if(k=="quoteBid")p.quoteBid=d;else if(k=="quoteAsk")p.quoteAsk=d;
 else if(k=="requested")p.requested=d;else if(k=="entry")p.entry=d;else if(k=="sl")p.sl=d;else if(k=="tp")p.tp=d;else if(k=="initialR")p.initialR=d;else if(k=="atrValue")p.atrValue=d;else if(k=="atrMultiplier")p.atrMultiplier=d;
 else if(k=="buffer")p.buffer=d;else if(k=="structure")p.structure=d;else if(k=="obstacle")p.obstacle=d;else if(k=="clearance")p.clearance=d;else if(k=="minRR")p.minRR=d;else if(k=="rawLot")p.rawLot=d;
 else if(k=="lot")p.lot=d;else if(k=="budget")p.budget=d;else if(k=="risk")p.risk=d;else if(k=="netGain")p.netGain=d;else if(k=="costsPerLot")p.costsPerLot=d;else if(k=="rr")p.rr=d;
 else if(k=="trailR")p.trailR=d;else if(k=="partialR")p.partialR=d;else if(k=="mfe")p.mfe=d;else if(k=="mae")p.mae=d;else if(k=="signalClose")p.signalClose=d;else if(k=="plannedSL")p.plannedSL=d;else if(k=="plannedTP")p.plannedTP=d;
 }
 FileClose(f);return p.version==3&&p.id!=""&&p.symbol!=""&&p.strategy!=""&&p.entry>0&&p.sl>0&&p.tp>0&&p.initialR>0&&MathIsValidNumber(p.initialR)&&p.lot>0&&p.budget>0&&p.minRR>0&&p.pivotLeft>0&&p.pivotRight>0&&p.maxAge>=p.pivotRight&&(p.timeframe==PERIOD_M5||p.timeframe==PERIOD_M15);
}
void PlanCritical(string message){criticalFailure=true;sessionState.authorized=false;Journal("plan_critical",message);Notify("Planejamento: entradas desarmadas | "+message);}
bool ClosedPlanData(string s,ENUM_TIMEFRAMES tf,MqlRates &bars[],double &h[],double &l[],double &c[],double &wilder){
 ArraySetAsSeries(bars,true);int n=CopyRates(s,tf,1,PlanHistoryBars,bars);if(n!=PlanHistoryBars)return false;
 ArrayResize(h,n);ArrayResize(l,n);ArrayResize(c,n);
 for(int j=0;j<n;j++){h[j]=bars[j].high;l[j]=bars[j].low;c[j]=bars[j].close;if(!MathIsValidNumber(h[j])||!MathIsValidNumber(l[j])||!MathIsValidNumber(c[j])||h[j]<l[j]||l[j]<=0||bars[j].time+PeriodSeconds(tf)>TimeTradeServer()||(j>0&&bars[j].time>=bars[j-1].time))return false;}
 wilder=WilderATR(h,l,c,n,14);return MathIsValidNumber(wilder)&&wilder>0;
}
bool SnapshotRoom(string destination){
 string prefix="FSSignal-"+accountScope+"-",name;string names[];long times[];
 long search=FileFindFirst(prefix+"*.csv",name);
 if(search!=INVALID_HANDLE){
 do {if(StringFind(name,prefix)==0&&StringSubstr(name,StringLen(name)-4)==".csv"){
 int n=ArraySize(names);ArrayResize(names,n+1);ArrayResize(times,n+1);names[n]=name;times[n]=FileGetInteger(name,FILE_MODIFY_DATE);
 }}while(FileFindNext(search,name));FileFindClose(search);
 }
 int count=ArraySize(names);bool replacing=FileIsExist(destination);if(replacing&&count<=PlanSnapshotMaxFiles)return true;
 int action=SnapshotCapacityAction(count,PlanSnapshotMaxFiles,PlanSnapshotPruneOldest);
 if(action==0){Journal("snapshot_limit","Snapshots pausados no limite="+(string)PlanSnapshotMaxFiles+"; negociação não depende desses arquivos");return false;}
 if(action==1)return true;
 // Only explicit opt-in prunes this account's FSSignal files. Never touch plans/history/credentials.
 int targetCount=replacing?PlanSnapshotMaxFiles:PlanSnapshotMaxFiles-1;
 while(count>targetCount){int oldest=-1;
 for(int i=0;i<ArraySize(names);i++)if(names[i]!=""&&names[i]!=destination&&(oldest<0||times[i]<times[oldest]))oldest=i;
 if(oldest<0||!FileDelete(names[oldest])){Journal("snapshot_limit","Não foi possível liberar espaço; snapshot novo não criado");return false;}
 Journal("snapshot_pruned","file="+names[oldest]);names[oldest]="";count--;
 }
 return true;
}
void SaveSignalSnapshot(int index,bool buy,double signalClose,double oldStop,double oldTarget){
 if(!PlanSaveSignalSnapshots)return;
 string s=symbols[index],id=s+"/"+lastStrategy+"/"+(string)(long)iTime(s,PERIOD_M5,0);PlanSettings cfg=PlanConfig(s);
 string path="FSSignal-"+accountScope+"-"+StringFormat("%I64X",TextFingerprint(id))+".csv";
 if(!SnapshotRoom(path))return;
 MqlRates bars[];double h[],l[],c[],wilder;MqlTick tick;
 if(!SymbolInfoTick(s,tick)||!ClosedPlanData(s,cfg.tf,bars,h,l,c,wilder)){Journal("snapshot_unavailable","plan="+id+" | closed candles/quote unavailable");return;}
 int f=FileOpen(path,FILE_WRITE|FILE_CSV|FILE_ANSI,';',CP_UTF8);if(f==INVALID_HANDLE){Journal("snapshot_unavailable","plan="+id+" | file error");return;}
 bool ok=FileWrite(f,"META",id,s,lastStrategy,buy?"BUY":"SELL",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),"SERVER",TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS),MQLInfoInteger(MQL_TESTER)?"TESTER_CLOCK":"TERMINAL_UTC",EnumToString(cfg.tf),DoubleToString(tick.bid,12),DoubleToString(tick.ask,12),DoubleToString(signalClose,12),DoubleToString(oldStop,12),DoubleToString(oldTarget,12),DoubleToString(RelevantEquity(),8),DoubleToString(RiskPercent,8),DoubleToString(CommissionPerLotRoundTurn,8),(string)SlippageReservePoints,DoubleToString(SymbolInfoDouble(s,SYMBOL_POINT),12),DoubleToString(SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE),12),SymbolInfoInteger(s,SYMBOL_DIGITS),(string)tick.time_msc)>0;
 for(int j=0;j<ArraySize(bars);j++)ok=(FileWrite(f,"BAR",j,(string)(long)bars[j].time,DoubleToString(bars[j].open,12),DoubleToString(h[j],12),DoubleToString(l[j],12),DoubleToString(c[j],12))>0)&&ok;
 FileFlush(f);FileClose(f);Journal(ok?"signal_snapshot":"snapshot_unavailable","plan="+id+" | file="+path+" | rows="+(string)ArraySize(bars));
}
string PlanSummary(TechnicalPlan &p){double pointSize=SymbolInfoDouble(p.symbol,SYMBOL_POINT),pip=PipSize(pointSize,(int)SymbolInfoInteger(p.symbol,SYMBOL_DIGITS));
 double distance=SignedTargetDistance(p.buy,p.entry,p.tp);
 string targetState=p.tp<=0?"NOT_CALCULATED":(distance<=0?"INVALID_SIDE":"VALID_GEOMETRY");
 string targetPips=p.tp>0&&pip>0?DoubleToString(distance/pip,2):"N/A";
 string grossRR=p.tp>0&&distance>0&&p.initialR>0?DoubleToString(distance/p.initialR,4):"N/A";
 string netRR=p.risk>0&&p.tp>0&&distance>0?DoubleToString(p.rr,4):"N/A";
 return "plan="+p.id+" | strategy="+p.strategy+" | regime="+p.regime+" | symbol="+p.symbol+" | side="+(p.buy?"BUY":"SELL")+" | tf="+EnumToString((ENUM_TIMEFRAMES)p.timeframe)+" | structure_time="+TimeToString(p.structureTime,TIME_DATE|TIME_SECONDS)+" | structure_bid="+DoubleToString(p.structure,8)+" | obstacle_time="+TimeToString(p.obstacleTime,TIME_DATE|TIME_SECONDS)+" | obstacle_bid="+DoubleToString(p.obstacle,8)+" | WilderATR14="+DoubleToString(p.atrValue,8)+" | multiplier="+DoubleToString(p.atrMultiplier,2)+" | buffer_pips="+DoubleToString(p.buffer/pip,2)+" | entry="+DoubleToString(p.entry,8)+" | SL="+DoubleToString(p.sl,8)+" | SL_pips="+DoubleToString(p.initialR/pip,2)+" | TP="+DoubleToString(p.tp,8)+" | TP_state="+targetState+" | TP_pips="+targetPips+" | raw_lot="+DoubleToString(p.rawLot,8)+" | lot="+DoubleToString(p.lot,8)+" | budget="+DoubleToString(p.budget,4)+" | risk="+DoubleToString(p.risk,4)+" | net_gain="+DoubleToString(p.netGain,4)+" | RR_gross="+grossRR+" | RR_net="+netRR+" | cost_per_lot="+DoubleToString(p.costsPerLot,4)+" | exit_policy="+(string)p.exitPolicy+" | currency="+p.currency+" | SL_structural="+DoubleToString(p.buy?p.structure-p.buffer:p.structure+p.buffer+p.quoteAsk-p.quoteBid,8)+" | schema=3 | timezone=SERVER";
}
bool ProjectPlanReward(TechnicalPlan &p,double &projected){
 double full=0,partWin=0;if(!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,p.symbol,1,p.entry,p.tp,full))return false;
 double part=0;
 if(p.exitPolicy==PARTIAL_AND_TRAIL&&AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING&&MathAbs(p.tp-p.entry)>p.partialR*p.initialR){
 part=Volume(p.symbol,p.lot/2);double minimum=SymbolInfoDouble(p.symbol,SYMBOL_VOLUME_MIN);
 if(part<minimum||p.lot-part<minimum)part=0;
 if(part>0&&!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,p.symbol,1,p.entry,p.entry+(p.buy?1:-1)*p.partialR*p.initialR,partWin))return false;
 }
 projected=ProjectedGrossWin(full,partWin,p.lot,part)-p.costsPerLot*p.lot;
 return MathIsValidNumber(projected);
}
bool EvaluateTechnicalEconomics(TechnicalPlan &p,double maxLot=0,double maxBudget=0){
 if(!NewOrderPlan(p.symbol,p.buy,p.entry,p.sl,p.tp,p.lot,p.risk))return false;
 if(maxLot>0){double originalRisk=p.risk,originalLot=p.lot;p.lot=ExtensionVolumeLimit(maxLot,p.lot);p.risk=originalRisk*p.lot/originalLot;}
 double loss=0,win=0,slip=0;
 if(!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,p.symbol,1,p.entry,p.sl,loss)||!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,p.symbol,1,p.entry,p.tp,win)||!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,p.symbol,1,p.entry,p.entry+(p.buy?-1:1)*SlippageReservePoints*SymbolInfoDouble(p.symbol,SYMBOL_POINT),slip)){Reject("Falha ao avaliar R:R líquido");return false;}
 p.costsPerLot=CommissionPerLotRoundTurn+MathAbs(slip)+PlanSwapReservePerLot;p.budget=RiskBudget(RelevantEquity(),RiskPercent);if(maxBudget>0)p.budget=MathMin(p.budget,maxBudget);if(p.risk>p.budget+1e-8){Reject("Risco alterou durante reavaliação do TP");return false;}p.rawLot=p.budget/(MathAbs(loss)+p.costsPerLot);
 if(!ProjectPlanReward(p,p.netGain)){Reject("Falha ao projetar saída/parcial líquida");return false;}
 p.rr=p.risk>0?p.netGain/p.risk:0;
 return true;
}
int SelectPlanObstacle(string symbol,const double &h[],const double &l[],const double &c[],int count,bool buy,double entryPrice,double pip,string planID){
 MqlRates m15[];ArraySetAsSeries(m15,true);int requested=PlanObstacleM15Lookback+PlanPivotLeft+1;
 int copied=CopyRates(symbol,PERIOD_M15,1,requested,m15);bool m15Ready=copied==requested;
 double mh[],ml[];if(m15Ready){ArrayResize(mh,copied);ArrayResize(ml,copied);
 for(int j=0;j<copied;j++){mh[j]=m15[j].high;ml[j]=m15[j].low;if(m15[j].time+PeriodSeconds(PERIOD_M15)>TimeTradeServer()||!MathIsValidNumber(mh[j])||!MathIsValidNumber(ml[j])||mh[j]<ml[j]||ml[j]<=0)m15Ready=false;}}
 if(!m15Ready&&PlanObstacleSelection!=ALL_CONFIRMED_PIVOTS)return -2;
 double tolerance=PlanObstacleTolerancePips*pip;int best=-1,selectedTouches=0,selectedSpan=0;bool selectedM15=false,selectedBroken=false;datetime selectedM15Time=0;
 int rejected=0;
 for(int i=PlanPivotRight;i<count-PlanPivotLeft&&i<=PlanStructureLookback;i++){
 bool highLevel=buy;double level=buy?h[i]:l[i];
 if((buy?level<=entryPrice:level>=entryPrice)||!(buy?ConfirmedPivot(h,count,i,PlanPivotLeft,PlanPivotRight,true):ConfirmedPivot(l,count,i,PlanPivotLeft,PlanPivotRight,false)))continue;
 int span=0,touches=PivotTouches(h,l,count,i,PlanPivotRight,highLevel,level,tolerance,PlanObstacleTouchSeparation,span);
 bool broken=PivotBroken(c,count,i,PlanPivotRight,highLevel,level,tolerance,PlanObstacleBreakCloses);
 int matched=m15Ready?ConfluencePivotIndex(mh,ml,copied,PlanPivotLeft,PlanPivotRight,highLevel,level,tolerance):-1;bool confluence=matched>=0;
 if(!ObstacleQualified((int)PlanObstacleSelection,touches,span,PlanObstacleMinTouches,PlanObstacleMinSpanBars,confluence,broken)){rejected++;continue;}
 if(best<0||(buy?level<h[best]:level>l[best])){best=i;selectedTouches=touches;selectedSpan=span;selectedM15=confluence;selectedBroken=broken;selectedM15Time=confluence?m15[matched].time:0;}
 }
 PlanSettings profile=PlanConfig(symbol);
 string classification=selectedBroken?"BROKEN_PIVOT_BASELINE":selectedM15?"M15_CONFLUENCE":(selectedTouches>=PlanObstacleMinTouches&&selectedSpan>=PlanObstacleMinSpanBars?"RETESTED_LOCAL":"LOCAL_PIVOT");
 Journal("obstacle_review","plan="+planID+" | source_tf="+EnumToString(profile.tf)+" | policy="+EnumToString(PlanObstacleSelection)+" | selected_index="+(string)best+" | classification="+(best<0?"NONE":classification)+" | touches="+(string)selectedTouches+" | span_bars="+(string)selectedSpan+" | m15_data="+(m15Ready?"READY":"UNAVAILABLE")+" | m15_confluence="+(string)(int)selectedM15+" | m15_pivot_time="+(selectedM15?TimeToString(selectedM15Time,TIME_DATE|TIME_SECONDS):"N/A")+" | broken_by_closed_candles="+(string)(int)selectedBroken+" | excluded_candidates="+(string)rejected+" | not_a_win_probability=1");
 return best;
}
bool PrepareTechnicalPlan(int index,bool buy,double signalClose,double oldStop,double oldTarget,TechnicalPlan &p){
 lastPlanSpaceRecheck=false;ZeroMemory(p);string s=symbols[index];PlanSettings cfg=PlanConfig(s);p.version=3;p.id=s+"/"+lastStrategy+"/"+(string)(long)iTime(s,PERIOD_M5,0);activePlanID=p.id;
 if(StringFind(s,"EURUSD")!=0&&StringFind(s,"USDJPY")!=0&&StringFind(s,"USDCHF")!=0&&StringFind(s,"GBPUSD")!=0){Reject("Sem perfil técnico explícito para o símbolo");return false;}
 p.symbol=s;p.strategy=lastStrategy;p.regime=lastRegime;p.currency=AccountInfoString(ACCOUNT_CURRENCY);p.buy=buy;p.timeframe=(int)cfg.tf;p.created=TimeTradeServer();p.signalClose=signalClose;
 p.lookback=PlanStructureLookback;p.pivotLeft=PlanPivotLeft;p.pivotRight=PlanPivotRight;p.maxAge=PlanMaxStructureAge;
 p.trailR=cfg.trailR;p.partialR=PlanPartialR;p.exitPolicy=(int)PlanExitPolicy;p.trailPolicy=(int)PlanTrailPolicy;
 if(SymbolInfoInteger(s,SYMBOL_CHART_MODE)!=SYMBOL_CHART_MODE_BID){Reject("Base de candles não é Bid; plano não suportado");return false;}
 MqlTick tick;if(!SymbolInfoTick(s,tick)||TimeCurrent()-tick.time>30||tick.bid<=0||tick.ask<tick.bid){Reject("Cotação ausente/antiga no plano");return false;}
 double pointSize=SymbolInfoDouble(s,SYMBOL_POINT),tickSize=SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE),pip=PipSize(pointSize,(int)SymbolInfoInteger(s,SYMBOL_DIGITS));
 if(pointSize<=0||tickSize<=0||pip<=0){Reject("Unidades inválidas");return false;}
 MqlRates bars[];double h[],l[],c[],wilder;
 if(!ClosedPlanData(s,cfg.tf,bars,h,l,c,wilder)){Reject("Candles fechados insuficientes/ATR Wilder indisponível");return false;}
 if(!SymbolInfoTick(s,tick)||TimeCurrent()-tick.time>30||tick.bid<=0||tick.ask<tick.bid){Reject("Cotação mudou/indisponível após carregar candles");return false;}
 p.quoteBid=tick.bid;p.quoteAsk=tick.ask;
 p.atrValue=wilder;p.atrMultiplier=cfg.multiplier;p.entry=buy?tick.ask:tick.bid;p.requested=p.entry;
 if(MathAbs(tick.bid-signalClose)>PlanMaxEntryDriftATR*wilder){Reject("Preço afastado do sinal; oportunidade expirada");return false;}
 int count=MathMin(PlanStructureLookback+PlanPivotLeft+1,ArraySize(h));
 int pivot=FindInvalidation(h,l,count,PlanPivotLeft,PlanPivotRight,PlanMaxStructureAge,buy,p.entry);
 int obstacle=SelectPlanObstacle(s,h,l,c,count,buy,p.entry,pip,p.id);
 if(pivot<0){Reject("Sem pivô de invalidação confirmado dentro da idade máxima");return false;}
 if(obstacle==-2){Reject("Dados M15 indisponíveis para qualificar obstáculos");return false;}
 if(obstacle<0){Reject("Sem obstáculo/alvo técnico confirmado; espaço desconhecido");return false;}
 p.structure=buy?l[pivot]:h[pivot];p.structureTime=bars[pivot].time;p.obstacle=buy?h[obstacle]:l[obstacle];p.obstacleTime=bars[obstacle].time;
 p.buffer=MathMax(cfg.bufferPips*pip,MathMax(PlanBufferATR*wilder,PlanBufferSpread*(tick.ask-tick.bid)));p.clearance=p.buffer;
 double minimum=(MathMax(SymbolInfoInteger(s,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(s,SYMBOL_TRADE_FREEZE_LEVEL))+2)*pointSize;
 p.sl=TechnicalStop(buy,p.entry,tick.bid,tick.ask,p.structure,p.buffer,MathMax(cfg.multiplier*wilder,PlanMinStopPips*pip),minimum,tickSize);p.initialR=MathAbs(p.entry-p.sl);
 if(!StopWithinLimit(p.initialR,cfg.maxStop,pip,tickSize)){Journal("plan_geometry",PlanSummary(p));Reject("Stop técnico excede máximo operacional; não será encurtado");return false;}
 p.tp=TechnicalTarget(buy,p.entry,tick.ask-tick.bid,p.obstacle,p.clearance,p.initialR,PlanMaxTargetR,tickSize);
 if(StrategyMode==LEGACY){double limit=MaxTPPoints*pointSize;p.tp=buy?TickDown(MathMin(p.tp,p.entry+limit),tickSize):TickUp(MathMax(p.tp,p.entry-limit),tickSize);}
 p.plannedSL=p.sl;p.plannedTP=p.tp;p.minRR=oldStop>0?oldTarget/oldStop:0;
 if(StrategyMode==MULTISTRATEGY){ResearchConfig cfig=Config(s);p.minRR=cfig.reward;}
 Journal("plan_geometry",PlanSummary(p)+" | bid="+DoubleToString(tick.bid,8)+" | ask="+DoubleToString(tick.ask,8)+" | point="+DoubleToString(pointSize,8)+" | pip="+DoubleToString(pip,8)+" | tick="+DoubleToString(tickSize,8)+" | thesis=existing_signal_confirmed");
 if(!TargetFits(buy,p.entry,p.sl,p.tp,p.obstacle,tick.ask-tick.bid,p.clearance,tickSize)){lastPlanSpaceRecheck=true;Reject("Obstáculo sem espaço para alvo executável");return false;}
 if(!EvaluateTechnicalEconomics(p))return false;
 Journal("plan_evaluation",PlanSummary(p));
 if(!MathIsValidNumber(p.rr)||p.minRR<=0||p.rr+1e-9<p.minRR||p.netGain<=0){
 bool extended=false;
 if(PlanAllowTargetExtension&&p.minRR>0){
 TechnicalPlan candidate;candidate=p;
 candidate.tp=TechnicalTarget(buy,p.entry,tick.ask-tick.bid,p.obstacle,p.clearance,p.initialR,PlanExtendedTargetMaxR,tickSize);
 if(StrategyMode==LEGACY){double limit=MaxTPPoints*pointSize;candidate.tp=buy?TickDown(MathMin(candidate.tp,p.entry+limit),tickSize):TickUp(MathMax(candidate.tp,p.entry-limit),tickSize);}
 if(TargetExtends(buy,p.tp,candidate.tp,tickSize)&&TargetFits(buy,p.entry,p.sl,candidate.tp,p.obstacle,tick.ask-tick.bid,p.clearance,tickSize)){
 if(!EvaluateTechnicalEconomics(candidate,p.lot,p.budget))return false;
 Journal("plan_target_extension_evaluation",PlanSummary(candidate)+" | previous_TP="+DoubleToString(p.tp,8)+" | same_obstacle=1 | SL_unchanged=1 | lot_not_increased=1");
 if(MathIsValidNumber(candidate.rr)&&candidate.rr+1e-9>=candidate.minRR&&candidate.netGain>0){candidate.plannedTP=candidate.tp;p=candidate;extended=true;}
 }
 }
 if(!extended){lastPlanSpaceRecheck=true;Reject("Espaço técnico não cobre R:R líquido mínimo; não será ignorado o obstáculo");return false;}
 }
 Journal("plan_accepted",PlanSummary(p)+" | decision=all_required_checks_passed_no_win_probability");
 return true;
}
bool IsTechnicalPosition(){ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);return FileIsExist(PositionPlanPath(id))||StringFind(PositionGetString(POSITION_COMMENT),"FS3:")==0||(GlobalVariableCheck(StateKey("v."+(string)id))&&GlobalVariableGet(StateKey("v."+(string)id))==3);}
string TechnicalOrderComment(TechnicalPlan &p){int last=-1,at=StringFind(p.id,"/");while(at>=0){last=at;at=StringFind(p.id,"/",at+1);}return "FS3:"+p.strategy+":"+(last>=0?StringSubstr(p.id,last+1):"UNKNOWN");}
// Reconcile fills by order/comment AND account/symbol, never by symbol alone.
double TechnicalExtraReserve(ulong ticket,double volume){
 if(!PositionSelectByTicket(ticket)||!IsTechnicalPosition())return 0;
 TechnicalPlan p;ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
 if(!LoadTechnicalPlan(PositionPlanPath(id),p))return 1e100;
 return MathMax(0,p.costsPerLot-CommissionPerLotRoundTurn)*volume;
}
bool CaptureTechnicalFill(ulong deal){
 if(!HistoryDealSelect(deal)||HistoryDealGetInteger(deal,DEAL_MAGIC)!=(long)MAGIC||HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN)return false;
 double openingSL=HistoryDealGetDouble(deal,DEAL_SL);
 string s=HistoryDealGetString(deal,DEAL_SYMBOL),comment=HistoryDealGetString(deal,DEAL_COMMENT);ulong id=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID),order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);
 TechnicalPlan p;bool existing=LoadTechnicalPlan(PositionPlanPath(id),p);
 if(!existing){if(!LoadTechnicalPlan(PendingPlanPath(s),p)){
 if(StringFind(comment,"FS3:")==0){GlobalVariableSet(StateKey("v."+(string)id),3);PlanCritical("Plano persistido ausente na execução; proteção do servidor preservada");}return false;}
 if((p.order==0||p.order!=order)&&comment!=TechnicalOrderComment(p))return false;
 }
 if(p.symbol!=s)return false;
 GlobalVariableSet(StateKey("v."+(string)id),3);GlobalVariableSet(StateKey("q."+(string)id),PolicyCode(p.strategy));
 ulong ticket=0;for(int j=0;j<PositionsTotal();j++){ulong candidate=PositionGetTicket(j);if(candidate>0&&(ulong)PositionGetInteger(POSITION_IDENTIFIER)==id){ticket=candidate;break;}}
 if(ticket==0){Journal("plan_fill_closed","plan="+p.id+" | position="+(string)id+" | position already absent; no duplicate order or close");return false;}
 if(p.audited&&PositionSelectByTicket(ticket)&&PositionGetDouble(POSITION_VOLUME)<=p.lot+1e-8&&MathAbs(PositionGetDouble(POSITION_PRICE_OPEN)-p.entry)<=SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE)*0.1)return true;
 if(!OwnedPosition(ticket)){PlanCritical("Titularidade misturada; plano não alterará posição");return false;}
 p.entry=PositionGetDouble(POSITION_PRICE_OPEN);double liveSL=PositionGetDouble(POSITION_SL);p.managedSL=liveSL;
 // Initial invalidation is not reconstructed from a potentially trailed current SL.
 p.sl=openingSL>0?openingSL:p.plannedSL;p.tp=PositionGetDouble(POSITION_TP);p.lot=PositionGetDouble(POSITION_VOLUME);p.initialR=MathAbs(p.entry-p.sl);p.order=order;
 double loss=0,win=0,slip=0,pointSize=SymbolInfoDouble(s,SYMBOL_POINT),tickSize=SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE);
 bool calculated=OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,s,p.lot,p.entry,p.sl,loss)&&OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,s,p.lot,p.entry,p.tp,win)&&OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,s,p.lot,p.entry,p.entry+(p.buy?-1:1)*SlippageReservePoints*pointSize,slip);
 double cost=p.costsPerLot*p.lot;
 p.risk=MathAbs(loss)+cost;if(!ProjectPlanReward(p,p.netGain))calculated=false;p.rr=p.risk>0?p.netGain/p.risk:0;
 double adverse=(p.buy?1:-1)*(p.entry-p.requested);
 bool bad=AccountInfoDouble(ACCOUNT_MARGIN_FREE)<0||!calculated||liveSL<=0||p.sl<=0||p.tp<=0||p.initialR<=0||!MathIsValidNumber(p.risk)||p.risk>p.budget+0.01||adverse>SlippageReservePoints*pointSize+tickSize*1e-6||MathAbs(p.sl-p.plannedSL)>tickSize*0.51||(p.buy?liveSL<p.sl-tickSize*0.51:liveSL>p.sl+tickSize*0.51)||MathAbs(p.tp-p.plannedTP)>tickSize*0.51||p.rr+1e-6<p.minRR;
 p.audited=true;p.breached=bad;
 if(!SaveTechnicalPlan(PositionPlanPath(id),p)){bad=true;p.breached=true;PlanCritical("Falha persistindo plano executado");}
 if(AggregateRisk()>RiskBudget(RelevantEquity(),MaxAggregateRiskPercent)+0.01){bad=true;p.breached=true;SaveTechnicalPlan(PositionPlanPath(id),p);}
 GlobalVariablesFlush();Journal("plan_fill",PlanSummary(p)+" | position="+(string)id+" | actual_risk_verified="+(string)(int)!bad);
 if(bad){PlanCritical("Execução fora do plano/risco/proteção; tentativa única de encerrar posição própria "+s);
 if(Identity()==accountIdentity&&Permissions()&&OwnedPosition(ticket)){
 bool closed=trade.PositionClose(ticket)&&Success();Journal("plan_protection_close","position="+(string)id+" | success="+(string)(int)closed+" | retcode="+(string)trade.ResultRetcode());}
 }
 return true;
}
bool RecoverTechnicalPosition(ulong ticket){
 if(!PositionSelectByTicket(ticket)||!IsTechnicalPosition())return false;
 ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);TechnicalPlan p;
 if(LoadTechnicalPlan(PositionPlanPath(id),p)){if(p.breached||!p.audited){PlanCritical("Plano recuperado com violação/execução não auditada; revisar antes de reativar");return true;}GlobalVariableSet(StateKey("v."+(string)id),3);GlobalVariableSet(StateKey("q."+(string)id),PolicyCode(p.strategy));Journal("plan_recovery","plan="+p.id+" | position="+(string)id+" | immutable_initial_R="+DoubleToString(p.initialR,8));return true;}
 if(HistorySelectByPosition(id)){ulong opening=0;for(int j=0;j<HistoryDealsTotal();j++){ulong d=HistoryDealGetTicket(j);if(HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_IN&&HistoryDealGetInteger(d,DEAL_MAGIC)==(long)MAGIC){opening=d;break;}}
 if(opening>0&&CaptureTechnicalFill(opening))return true;}
 GlobalVariableSet(StateKey("v."+(string)id),3);PlanCritical("Não foi possível recuperar plano técnico; sem reconstruir stop por suposição");return true;
}
void ManageTechnicalPosition(ulong ticket){
 if(!OwnedPosition(ticket))return;ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);TechnicalPlan p;
 if(!LoadTechnicalPlan(PositionPlanPath(id),p)){RecoverTechnicalPosition(ticket);return;}
 if(!p.audited||p.breached)return;
 if(!HistorySelectByPosition(id)){PlanCritical("Histórico indisponível para reconciliar parcial técnica");return;}
 for(int j=0;j<HistoryDealsTotal();j++){ulong d=HistoryDealGetTicket(j);long e=HistoryDealGetInteger(d,DEAL_ENTRY);if(e==DEAL_ENTRY_OUT||e==DEAL_ENTRY_OUT_BY||e==DEAL_ENTRY_INOUT){GlobalVariableSet(Key(id),1);break;}}
 if(!OwnedPosition(ticket))return;
 MqlTick tick;if(!SymbolInfoTick(p.symbol,tick)||TimeCurrent()-tick.time>30)return;
 double mark=p.buy?tick.bid:tick.ask,gain=(p.buy?1:-1)*(mark-p.entry);p.mfe=MathMax(p.mfe,gain);p.mae=MathMax(p.mae,-gain);
 if(!SaveTechnicalPlan(PositionPlanPath(id),p)){PlanCritical("Falha salvando estado de gestão");return;}
 string traceKey=StateKey("u."+(string)id);datetime traceBar=iTime(p.symbol,PERIOD_M5,0);
 if(!GlobalVariableCheck(traceKey)||GlobalVariableGet(traceKey)!=(double)traceBar){GlobalVariableSet(traceKey,traceBar);Journal("plan_management","plan="+p.id+" | position="+(string)id+" | initial_R="+DoubleToString(p.initialR,8)+" | gain_R="+DoubleToString(gain/p.initialR,4)+" | trail_trigger_R="+DoubleToString(p.trailR,4)+" | partial_trigger_R="+DoubleToString(p.partialR,4));}
 if(p.exitPolicy==FULL_TECHNICAL_TARGET)return; // Fixed server SL/TP; experiment without partial/trailing.
 if(ManagementProgress(gain,p.initialR,p.trailR)){
 MqlRates bars[];double h[],l[],c[],wilder;
 if(ClosedPlanData(p.symbol,(ENUM_TIMEFRAMES)p.timeframe,bars,h,l,c,wilder)){
 int pivot=FindInvalidation(h,l,MathMin(p.lookback+p.pivotLeft+1,ArraySize(h)),p.pivotLeft,p.pivotRight,p.maxAge,p.buy,mark);
 if(pivot>=0){double pointSize=SymbolInfoDouble(p.symbol,SYMBOL_POINT),tickSize=SymbolInfoDouble(p.symbol,SYMBOL_TRADE_TICK_SIZE);
 double structural=p.buy?l[pivot]-p.buffer:h[pivot]+p.buffer+(tick.ask-tick.bid);
 double candidate=structural;
 if(p.trailPolicy==VOLATILITY_WITH_STRUCTURE){double volatileStop=mark+(p.buy?-1:1)*p.atrMultiplier*wilder;candidate=p.buy?MathMin(structural,volatileStop):MathMax(structural,volatileStop);}
 candidate=p.buy?TickDown(candidate,tickSize):TickUp(candidate,tickSize);
 if(!PositionSelectByTicket(ticket))return;double old=PositionGetDouble(POSITION_SL),currentTP=PositionGetDouble(POSITION_TP);
 double minimum=(MathMax(SymbolInfoInteger(p.symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(p.symbol,SYMBOL_TRADE_FREEZE_LEVEL))+2)*pointSize;
 if(StopImproves(p.buy,old,candidate,pointSize)&&(p.buy?candidate<tick.bid-minimum:candidate>tick.ask+minimum)&&Identity()==accountIdentity&&Permissions()){
 bool ok=trade.PositionModify(ticket,candidate,currentTP)&&Success();if(ok){p.managedSL=candidate;if(!SaveTechnicalPlan(PositionPlanPath(id),p))PlanCritical("Falha persistindo stop modificado");}Journal(ok?"plan_trailing_ok":"plan_trailing_reject","plan="+p.id+" | position="+(string)id+" | old="+DoubleToString(old,8)+" | next="+DoubleToString(candidate,8)+" | gain_R="+DoubleToString(gain/p.initialR,4)+" | retcode="+(string)trade.ResultRetcode());
 }
 }
 }
 }
 if(ManagementProgress(gain,p.initialR,p.partialR)&&!GlobalVariableCheck(Key(id))&&AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING&&OwnedPosition(ticket)){
 double volume=PositionGetDouble(POSITION_VOLUME),part=Volume(p.symbol,volume/2),minimum=SymbolInfoDouble(p.symbol,SYMBOL_VOLUME_MIN);
 if(part>=minimum&&volume-part>=minimum&&Identity()==accountIdentity&&Permissions()){
 if(trade.PositionClosePartial(ticket,part)&&Success()){GlobalVariableSet(Key(id),1);GlobalVariablesFlush();Journal("plan_partial","plan="+p.id+" | position="+(string)id+" | volume="+DoubleToString(part,8));Notify("Parcial técnica "+p.symbol,p.strategy);}else Journal("plan_partial_reject","plan="+p.id+" | position="+(string)id+" | retcode="+(string)trade.ResultRetcode());}
 }
}
void AuditTechnicalExit(ulong deal){
 if(!HistoryDealSelect(deal))return;ulong id=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);long entryType=HistoryDealGetInteger(deal,DEAL_ENTRY);
 if(entryType!=DEAL_ENTRY_OUT&&entryType!=DEAL_ENTRY_OUT_BY&&entryType!=DEAL_ENTRY_INOUT)return;
 TechnicalPlan p;if(!LoadTechnicalPlan(PositionPlanPath(id),p))return;
 string reason=EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(deal,DEAL_REASON));
 double exitSL=HistoryDealGetDouble(deal,DEAL_SL),exitTP=HistoryDealGetDouble(deal,DEAL_TP),tolerance=SymbolInfoDouble(p.symbol,SYMBOL_TRADE_TICK_SIZE)*0.51;
 bool protectionMatch=MathAbs(exitSL-p.managedSL)<=tolerance&&MathAbs(exitTP-p.tp)<=tolerance;
 double exitPrice=HistoryDealGetDouble(deal,DEAL_PRICE),gain=(p.buy?1:-1)*(exitPrice-p.entry);p.mfe=MathMax(p.mfe,gain);p.mae=MathMax(p.mae,-gain);
 bool stillOpen=false;for(int j=0;j<PositionsTotal();j++){if(PositionGetTicket(j)>0&&(ulong)PositionGetInteger(POSITION_IDENTIFIER)==id)stillOpen=true;}
 double net=0;if(HistorySelectByPosition(id)){for(int j=0;j<HistoryDealsTotal();j++){ulong d=HistoryDealGetTicket(j);net+=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_FEE);}}
 SaveTechnicalPlan(PositionPlanPath(id),p);
 MqlDateTime opened;TimeToStruct(p.created,opened);
 Journal("plan_exit","plan="+p.id+" | strategy="+p.strategy+" | symbol="+p.symbol+" | regime="+p.regime+" | server_open_hour="+(string)opened.hour+" | position="+(string)id+" | deal="+(string)deal+" | official_reason="+reason+" | protection_matches_last_record="+(string)(int)protectionMatch+" | exit_SL="+DoubleToString(exitSL,8)+" | exit_TP="+DoubleToString(exitTP,8)+" | fully_closed="+(string)(int)!stillOpen+" | cumulative_net="+DoubleToString(net,8)+" | net_R="+DoubleToString(p.risk>0?net/p.risk:0,8)+" | duration_seconds="+(string)(long)(TimeTradeServer()-p.created)+" | MFE_sampled_R="+DoubleToString(p.mfe/p.initialR,8)+" | MAE_sampled_R="+DoubleToString(p.mae/p.initialR,8)+" | breached="+(string)(int)p.breached+" | exit_policy="+(string)p.exitPolicy);
 HistoryDealSelect(deal);
}
#endif
