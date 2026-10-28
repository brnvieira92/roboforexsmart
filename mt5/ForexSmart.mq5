#property strict
#property version "2.02"
#property description "Forex Smart | smartTrade | Demo validation required"
#include <Trade/Trade.mqh>
#include "Include/ForexSmartTelegram.mqh"
#include "Include/ForexSmartCore.mqh"
input bool AutoTrade=false;
input string Pairs="EURUSD#,USDJPY#,GBPUSD#,USDCHF#";
input double RiskPercent=0.25;
input int MinTPPoints=100;
input int MaxTPPoints=500;
input int MaxSpreadPoints=25;
input double DailyLossPercent=2.0;
input bool PushNotifications=false;
input bool TelegramNotifications=false;
input StrategySelection StrategyMode=LEGACY;
input bool TesterAuthorizeSession=false; // Applies only inside Strategy Tester; ignored in a connected account.
input bool EnableEUR_T01=false;
input bool EnableJPY_B01=false;
input bool EnableCHF_R01=false;
input bool EnableGBP_T01=false;
input bool UseReferenceCapital=false;
input double ReferenceCapital=50.00;
input bool CommissionEstimateConfirmed=false;
input double CommissionPerLotRoundTurn=0;
input int SlippageReservePoints=2;
input double MaxSpreadStopRatio=0.25;
input double MaxCostRiskRatio=0.30;
input double MaxAggregateRiskPercent=0.50;
input int MaxSameUSDPositions=1;
input double EUR_ADX=20,EUR_StopATR=1.2,EUR_RewardR=2;
input double JPY_ADX=20,JPY_StopATR=1.5,JPY_RewardR=2;
input double CHF_ADX=18,CHF_StopATR=1.5,CHF_RewardR=1.5;
input double GBP_ADX=22,GBP_StopATR=1.5,GBP_RewardR=2;
input int EUR_SpreadPoints=25,JPY_SpreadPoints=25,CHF_SpreadPoints=25,GBP_SpreadPoints=25;
input double EUR_CostRatio=0.30,JPY_CostRatio=0.30,CHF_CostRatio=0.30,GBP_CostRatio=0.30;
input double CHF_FlatATR=0.10,CHF_RSI_Low=30,CHF_RSI_High=70;
input int RangeBars=12;
input double ATRExpansion=1.1,BreakoutATRBuffer=0.1;
input int ResearchStartHour=8,ResearchEndHour=20;
input bool UseEconomicCalendar=true;
input bool AllowResearchWithoutCalendar=false;
input int NewsMinutes=30;
const ulong MAGIC=2601027;
CTrade trade;
string symbols[];
string entrySymbols[];
int fastHandles[],slowHandles[],atrHandles[];
datetime lastbar[];
double dayEquity=0;
int dayKey=-1;
bool entriesPaused=false;
bool lossNotified=false;
string latest="Inicializando";
#include "Include/ForexSmartAccount.mqh"
#include "Include/ForexSmartResearch.mqh"
#include "Include/ForexSmartRisk.mqh"
string lockKey="";double lockLease=0;bool leaseOwned=false;
bool OwnLease(){
 if(lockKey==""||!leaseOwned)return false;
 double next=(double)TimeLocal()+15;
 if(!GlobalVariableSetOnCondition(lockKey,next,lockLease)){sessionState.authorized=false;leaseOwned=false;return false;}
 lockLease=next;return true;
}
bool AcquireLease(){lockKey=StateKey("lease");GlobalVariableTemp(lockKey);
 double prior=GlobalVariableGet(lockKey);if(prior>TimeLocal())return false;
 lockLease=(double)TimeLocal()+15;leaseOwned=GlobalVariableSetOnCondition(lockKey,lockLease,prior);return leaseOwned;
}
void ReleaseLease(){if(leaseOwned&&lockKey!="")GlobalVariableSetOnCondition(lockKey,0,lockLease);lockKey="";lockLease=0;leaseOwned=false;}
void Notify(string text,string responsible="OPERATIONAL"){latest=text; Print(text); Alert(text); if(PushNotifications) SendNotification(text);TelegramQueue("Forex Smart | "+AccountKind()+" | "+ModeName()+" | "+responsible+"\nServidor: "+TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS)+"\n"+text);}
string Key(ulong id){return StateKey("p."+(string)id);}
double Value(int handle,int shift){double b[1]; if(CopyBuffer(handle,0,shift,1,b)!=1) return EMPTY_VALUE; return b[0];}
void Journal(string type,string detail){
 int f=FileOpen("ForexSmart-"+accountScope+"-history.csv",FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_READ|FILE_ANSI,';',CP_UTF8);
 if(f==INVALID_HANDLE){criticalFailure=true;sessionState.authorized=false;Print("Journal error: ",GetLastError());return;}
 FileSeek(f,0,SEEK_END); uint written=FileWrite(f,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),type,detail); FileFlush(f);FileClose(f);
 if(written==0){criticalFailure=true;sessionState.authorized=false;Print("Forex Smart: falha ao escrever histórico; entradas desarmadas.");}
}
bool Success(){uint r=trade.ResultRetcode();return r==TRADE_RETCODE_DONE||r==TRADE_RETCODE_DONE_PARTIAL;}
void RefreshDay(){MqlDateTime d;TimeToStruct(TimeTradeServer(),d);int key=d.year*1000+d.day_of_year;
 if(key!=dayKey){lossNotified=false;dayKey=key;string k=StateKey((UseReferenceCapital&&AccountKind()=="DEMO"?"dr.":"d.")+(string)key);
 if(GlobalVariableCheck(k))dayEquity=GlobalVariableGet(k);else{dayEquity=RelevantEquity();GlobalVariableSet(k,dayEquity);}}}
bool LossLimit(){return DailyBlocked(RelevantEquity(),dayEquity,DailyLossPercent);}
double Price(string s,double p){double tick=SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE);if(tick<=0||!MathIsValidNumber(p))return 0;return NormalizeDouble(MathRound(p/tick)*tick,(int)SymbolInfoInteger(s,SYMBOL_DIGITS));}
double Volume(string s,double v){double step=SymbolInfoDouble(s,SYMBOL_VOLUME_STEP);return NormalizeDouble(FloorVolume(v,step,SymbolInfoDouble(s,SYMBOL_VOLUME_MAX)),8);}
#include "Include/ForexSmartRecovery.mqh"
void Manage(){
 if(!Permissions()||Identity()!=accountIdentity)return; // Existing server SL/TP remain in place when terminal cannot trade.
 for(int p=PositionsTotal()-1;p>=0;p--){ulong ticket=PositionGetTicket(p);if(ticket==0||!OwnedPosition(ticket))continue;
 string s=PositionGetString(POSITION_SYMBOL);int idx=-1;for(int j=0;j<ArraySize(symbols);j++)if(symbols[j]==s)idx=j;if(idx<0)continue;
 double a=Value(atrHandles[idx],1);if(a==EMPTY_VALUE||a<=0)continue;
 bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;MqlTick t;if(!SymbolInfoTick(s,t))continue;
 if(TimeCurrent()-t.time>30)continue;
 double current=buy?t.bid:t.ask,entry=PositionGetDouble(POSITION_PRICE_OPEN),gain=(buy?1:-1)*(current-entry);
 if(SymbolInfoDouble(s,SYMBOL_POINT)<=0||SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE)<=0)continue;
 double point=SymbolInfoDouble(s,SYMBOL_POINT),old=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
 string comment=PositionGetString(POSITION_COMMENT);
 string positionStrategy="LEGACY";string policyKey=StateKey("q."+(string)PositionGetInteger(POSITION_IDENTIFIER));
 if(GlobalVariableCheck(policyKey))positionStrategy=PolicyName((int)GlobalVariableGet(policyKey));else if(StringFind(comment,"FS2:")==0)positionStrategy=StringSubstr(comment,4);
 bool researchPosition=StringFind(comment,"FS2:")==0||GlobalVariableCheck(StateKey("q."+(string)PositionGetInteger(POSITION_IDENTIFIER)));
 double initialRisk=0;string riskKey=StateKey("r."+(string)PositionGetInteger(POSITION_IDENTIFIER));
 if(GlobalVariableCheck(riskKey))initialRisk=GlobalVariableGet(riskKey);
 if(researchPosition&&initialRisk<=0){Journal("recovery","Missing initial R: no TP/partial change for "+s);continue;}
 double managementATR=researchPosition?initialRisk:a;
 string traceKey=StateKey("t."+(string)PositionGetInteger(POSITION_IDENTIFIER));datetime traceBar=iTime(s,PERIOD_M5,0);
 if(!GlobalVariableCheck(traceKey)||GlobalVariableGet(traceKey)!=(double)traceBar){GlobalVariableSet(traceKey,(double)traceBar);Journal("management_state",s+" | gain="+DoubleToString(gain,8)+" | trigger="+DoubleToString(managementATR,8)+" | partial_trigger="+DoubleToString(1.5*managementATR,8)+" | current_sl="+DoubleToString(old,8));}
 // Reassess target from current trend strength, bounded relative to entry.
 double f=Value(fastHandles[idx],1),slo=Value(slowHandles[idx],1);
 if(!researchPosition&&f!=EMPTY_VALUE&&slo!=EMPTY_VALUE){
 double strength=MathMin(1.0,MathAbs(f-slo)/a);
 double targetPoints=MathMax(MinTPPoints,MathMin(MaxTPPoints,a/point*(1+2*strength)));
 double proposed=Price(s,entry+(buy?1:-1)*targetPoints*point);
 double safeDistance=(MathMax(SymbolInfoInteger(s,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(s,SYMBOL_TRADE_FREEZE_LEVEL))+2)*point;
 if(MathAbs(proposed-tp)>a*0.25&&(buy?proposed>t.ask+safeDistance:proposed<t.bid-safeDistance)){
 if(trade.PositionModify(ticket,old,proposed)&&Success())tp=proposed;
 }
 }
 double distance=MathMax(managementATR, (MathMax(SymbolInfoInteger(s,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(s,SYMBOL_TRADE_FREEZE_LEVEL))+2)*point);
 if(gain>=managementATR){double next=Price(s,TrailingCandidate(buy,entry,current,distance));
 if(StopImproves(buy,old,next,point)&&((buy&&next<t.bid-distance+point)||(!buy&&next>t.ask+distance-point))){
 Journal("trailing_request",s+" | gain="+DoubleToString(gain,8)+" | trigger="+DoubleToString(managementATR,8)+" | old="+DoubleToString(old,8)+" | next="+DoubleToString(next,8));
 bool modified=trade.PositionModify(ticket,next,tp)&&Success();
 if(!modified){Print("Trailing rejected: ",trade.ResultRetcodeDescription());Journal("trailing_reject",s+" | "+trade.ResultRetcodeDescription());}
 else {Journal("trailing_ok",s+" | SL="+DoubleToString(next,8));}

 if(modified&&((buy&&old<entry&&next>=entry)||(!buy&&(old==0||old>entry)&&next<=entry)))TelegramQueue("Forex Smart | "+AccountKind()+" | "+ModeName()+" | "+positionStrategy+" | Stop no preço de entrada ou melhor | "+s+" | SL "+DoubleToString(next,(int)SymbolInfoInteger(s,SYMBOL_DIGITS))+" | Custos ainda podem causar perda.");}}
 ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);string key=Key(id);
 if(gain>=1.5*managementATR&&!GlobalVariableCheck(key)){
 double vol=PositionGetDouble(POSITION_VOLUME),part=Volume(s,vol/2),minimum=SymbolInfoDouble(s,SYMBOL_VOLUME_MIN);
 // Partial close is supported only on hedging accounts. Never open an opposite position on netting accounts.
 if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING&&part>=minimum&&vol-part>=minimum){
 if(trade.PositionClosePartial(ticket,part)&&Success()){GlobalVariableSet(key,1);GlobalVariablesFlush();Notify("Parcial: "+s,positionStrategy);Journal("partial",s);}}
 }
 }
}
void Scan(int i){
 string s=symbols[i];bool configured=false;for(int j=0;j<ArraySize(entrySymbols);j++)if(s==entrySymbols[j])configured=true;if(!configured)return;datetime bar=iTime(s,PERIOD_M5,0);if(bar==0||bar==lastbar[i])return;
 double f=Value(fastHandles[i],1),sl=Value(slowHandles[i],1),a=Value(atrHandles[i],1);if(f==EMPTY_VALUE||sl==EMPTY_VALUE||a==EMPTY_VALUE||a<=0)return;
 MqlRates rates[];ArraySetAsSeries(rates,true);if(CopyRates(s,PERIOD_M5,1,3,rates)!=3)return;
 lastbar[i]=bar;GlobalVariableSet(BarKey(s),bar);
 lastStrategy="LEGACY";lastRegime="LEGACY";
 int direction=LegacyDirection(f,sl,rates[1].close,rates[0].close);
 double stop=LegacyStop(a),target=LegacyTarget(a,SymbolInfoDouble(s,SYMBOL_POINT),f,sl,MinTPPoints,MaxTPPoints);
 if(StrategyMode==MULTISTRATEGY)direction=ResearchSignal(i,a,stop,target);
 bool buy=direction>0;if(direction==0)return;
 MqlTick tick;if(!SymbolInfoTick(s,tick)||TimeCurrent()-tick.time>30)return;
 double point=SymbolInfoDouble(s,SYMBOL_POINT);int maxSpread=MaxSpreadPoints;if(StrategyMode==MULTISTRATEGY){ResearchConfig config=Config(s);maxSpread=MathMin(maxSpread,config.spread);}
 if((tick.ask-tick.bid)/point>maxSpread){Reject("Spread máximo: "+s);return;}
 string side=buy?"COMPRA":"VENDA";Notify("Oportunidade "+side+" "+s,lastStrategy);Journal("signal",side+" "+s);
 stop=MathMax(stop,(SymbolInfoInteger(s,SYMBOL_TRADE_STOPS_LEVEL)+2)*point);
 double entry=buy?tick.ask:tick.bid,stopPrice=Price(s,entry+(buy?-stop:stop)),targetPrice=Price(s,entry+(buy?target:-target));
 double lot=0,expected=0;
 if(!NewOrderPlan(s,buy,entry,stopPrice,targetPrice,lot,expected))return;
 // Recheck account immediately before dispatch; shared lease excludes other local instances.
 if(Identity()!=accountIdentity||!OwnLease()||!EntrySession()){Reject("Sessão alterada antes do envio");return;}
 trade.SetTypeFillingBySymbol(s);
 bool ok=trade.PositionOpen(s,buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,lot,entry,stopPrice,targetPrice,StrategyMode==LEGACY?"Forex Smart":"FS2:"+lastStrategy);
 if(trade.ResultRetcode()==TRADE_RETCODE_PLACED){criticalFailure=true;sessionState.authorized=false;Journal("critical","Order accepted but not yet filled: reconcile before reactivation");}
 if(!ok||!Success()){Print("Entry rejected: ",trade.ResultRetcodeDescription());Journal("reject",s+" "+trade.ResultRetcodeDescription());
 if(trade.ResultRetcode()==TRADE_RETCODE_INVALID_STOPS||trade.ResultRetcode()==TRADE_RETCODE_NO_MONEY){criticalFailure=true;sessionState.authorized=false;}}
 else {
 if(StrategyMode==MULTISTRATEGY&&HistoryDealSelect(trade.ResultDeal())){ulong id=(ulong)HistoryDealGetInteger(trade.ResultDeal(),DEAL_POSITION_ID);GlobalVariableSet(StateKey("r."+(string)id),MathAbs(entry-stopPrice));GlobalVariableSet(StateKey("q."+(string)id),PolicyCode(lastStrategy));GlobalVariablesFlush();}
 Journal("execution",s+" | requested="+DoubleToString(entry,8)+" | filled="+DoubleToString(trade.ResultPrice(),8)+" | deviation_pts="+DoubleToString(MathAbs(trade.ResultPrice()-entry)/point,2));}
}
void Button(string name,string text,int x){ObjectCreate(0,name,OBJ_BUTTON,0,0,0);ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,name,OBJPROP_YDISTANCE,25);ObjectSetInteger(0,name,OBJPROP_XSIZE,130);ObjectSetString(0,name,OBJPROP_TEXT,text);ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clrDarkGreen);ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);}
int OnInit(){
 if(EUR_CostRatio<=0||JPY_CostRatio<=0||CHF_CostRatio<=0||GBP_CostRatio<=0)return INIT_PARAMETERS_INCORRECT;
 if(ReferenceCapital<=0||CommissionPerLotRoundTurn<0||SlippageReservePoints<0||MaxSpreadStopRatio<=0||MaxCostRiskRatio<=0||MaxAggregateRiskPercent<=0||MaxAggregateRiskPercent>0.5||MaxSameUSDPositions<1||MaxSameUSDPositions>2||RangeBars<3||RangeBars>100||ResearchStartHour<0||ResearchEndHour>24||ResearchStartHour>=ResearchEndHour||NewsMinutes<0||ATRExpansion<=0||BreakoutATRBuffer<0||CHF_RSI_Low<=0||CHF_RSI_High>=100||CHF_RSI_Low>=CHF_RSI_High||CHF_FlatATR<0||EUR_ADX<=0||JPY_ADX<=0||CHF_ADX<=0||GBP_ADX<=0||EUR_StopATR<=0||JPY_StopATR<=0||CHF_StopATR<=0||GBP_StopATR<=0||EUR_RewardR<=0||JPY_RewardR<=0||CHF_RewardR<=0||GBP_RewardR<=0||EUR_SpreadPoints<=0||JPY_SpreadPoints<=0||CHF_SpreadPoints<=0||GBP_SpreadPoints<=0)return INIT_PARAMETERS_INCORRECT;
 if(RiskPercent<=0||RiskPercent>2||MinTPPoints<=0||MaxTPPoints<MinTPPoints||DailyLossPercent<=0||DailyLossPercent>10||MaxSpreadPoints<=0)return INIT_PARAMETERS_INCORRECT;
 SyncAccount();if(!AcquireLease()){Print("Outra instância administra esta conta neste terminal; aguarde 15s após falha.");return INIT_FAILED;}
 int n=StringSplit(Pairs,',',symbols);if(n<1)return INIT_PARAMETERS_INCORRECT;
 ArrayResize(entrySymbols,n);for(int j=0;j<n;j++){StringTrimLeft(symbols[j]);StringTrimRight(symbols[j]);entrySymbols[j]=symbols[j];}
 for(int p=0;p<PositionsTotal();p++){if(PositionGetTicket(p)==0||PositionGetInteger(POSITION_MAGIC)!=(long)MAGIC)continue;string sym=PositionGetString(POSITION_SYMBOL);bool found=false;for(int j=0;j<n;j++)if(symbols[j]==sym)found=true;if(!found){ArrayResize(symbols,++n);symbols[n-1]=sym;}}

 ArrayResize(fastHandles,n);ArrayResize(slowHandles,n);ArrayResize(atrHandles,n);ArrayResize(lastbar,n);ArrayInitialize(lastbar,0);
 for(int i=0;i<n;i++){StringTrimLeft(symbols[i]);StringTrimRight(symbols[i]);for(int j=0;j<i;j++)if(symbols[j]==symbols[i])return INIT_PARAMETERS_INCORRECT;if(!SymbolSelect(symbols[i],true))return INIT_FAILED;
 if(GlobalVariableCheck(BarKey(symbols[i])))lastbar[i]=(datetime)GlobalVariableGet(BarKey(symbols[i]));
 fastHandles[i]=iMA(symbols[i],PERIOD_M5,9,0,MODE_EMA,PRICE_CLOSE);slowHandles[i]=iMA(symbols[i],PERIOD_M5,21,0,MODE_EMA,PRICE_CLOSE);atrHandles[i]=iATR(symbols[i],PERIOD_M5,14);
 if(fastHandles[i]==INVALID_HANDLE||slowHandles[i]==INVALID_HANDLE||atrHandles[i]==INVALID_HANDLE)return INIT_FAILED;}
 if(StrategyMode==MULTISTRATEGY&&!ResearchInit())return INIT_FAILED;
 trade.SetExpertMagicNumber(MAGIC);trade.SetDeviationInPoints(SlippageReservePoints);RefreshDay();EventSetTimer(2);
 RecoverState();
 if(MQLInfoInteger(MQL_TESTER)&&TesterAuthorizeSession&&AutoTrade&&AccountKind()!="CONTEST")sessionState.authorized=true;
 ChartSetInteger(0,CHART_COLOR_BACKGROUND,clrBlack);ChartSetInteger(0,CHART_COLOR_FOREGROUND,clrWhite);ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,clrLime);
 Button("FS.pause","Pausar entradas",15);Button("FS.status","Status",155);Button("FS.arm","ATIVAR "+AccountKind(),295);Button("FS.emergency","EMERGÊNCIA",435);
 if(TelegramInit(TelegramNotifications))TelegramQueue("Forex Smart conectado | "+AccountKind()+" | "+ModeName()+" | "+lastStrategy+" | "+(AutoTrade?"Automático":"Alertas")+" | Pares: "+Pairs);
 return INIT_SUCCEEDED;
}
void Metrics(int &wins,int &losses,double &net){
 wins=0;losses=0;net=0;
 if(!HistorySelect(0,TimeCurrent()))return;
 for(int i=0;i<HistoryDealsTotal();i++){ulong deal=HistoryDealGetTicket(i);
 if(HistoryDealGetInteger(deal,DEAL_MAGIC)!=(long)MAGIC)continue;
 long kind=HistoryDealGetInteger(deal,DEAL_TYPE);if(kind!=DEAL_TYPE_BUY&&kind!=DEAL_TYPE_SELL)continue;
 double result=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_SWAP)+HistoryDealGetDouble(deal,DEAL_COMMISSION)+HistoryDealGetDouble(deal,DEAL_FEE);net+=result;
 long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);
 if(entry==DEAL_ENTRY_OUT||entry==DEAL_ENTRY_OUT_BY||entry==DEAL_ENTRY_INOUT){if(result>0)wins++;else if(result<0)losses++;}
 }
}
void OnTimer(){
 if(Identity()!=accountIdentity){ReleaseLease();SyncAccount();if(!AcquireLease()){criticalFailure=true;return;}RecoverState();}
 if(!OwnLease()){criticalFailure=true;Comment("Forex Smart: lease perdida. Reanexe uma única instância; novas entradas desarmadas.");return;}
 if(!TerminalInfoInteger(TERMINAL_CONNECTED))sessionState.authorized=false;
 RefreshDay();
 if(LossLimit()&&!lossNotified){lossNotified=true;Notify("Limite diário atingido: novas entradas bloqueadas; gestão continua.");}Manage();for(int i=0;i<ArraySize(symbols);i++)Scan(i);
 ObjectSetString(0,"FS.arm",OBJPROP_TEXT,(sessionState.authorized?"DESARMAR ":"ATIVAR ")+AccountKind());
 ObjectSetInteger(0,"FS.arm",OBJPROP_BGCOLOR,sessionState.authorized&&AccountKind()=="REAL"?clrRed:clrDarkGreen);
 int wins,losses;double net;Metrics(wins,losses,net);
 Comment("smartTrade | FOREX SMART | ",AccountKind()," | ",ModeName(),"\nSessão: ",sessionState.authorized?"AUTORIZADA":"DESARMADA",emergencyStop?" | EMERGÊNCIA":"","\nModo: ",AutoTrade?"Automático":"Alertas",entriesPaused?" | PAUSADO":"",LossLimit()?" | Limite diário":"",
 "\nSaldo: ",DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)," | Equity: ",DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2),
 "\nRisco %: ",RiskPercent," | Agregado estimado: ",DoubleToString(AggregateRisk(),2)," | Dia: ",DoubleToString(RelevantEquity()-dayEquity,2),
 "\nRegime: ",lastRegime," | Estratégia: ",lastStrategy," | Rejeição: ",lastReject,
 "\nPosições da conta: ",PositionsTotal()," / 2 | Pares: ",ArraySize(symbols),
 "\nNegócios de saída positivos/negativos: ",wins," / ",losses," | Líquido histórico EA: ",DoubleToString(net,2),
 "\nServidor: ",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS)," | UTC: ",TimeToString(TimeGMT(),TIME_SECONDS),
 "\nTelegram: ",TgReady?"habilitado (ver Experts)":"desativado/indisponível",
 "\n",latest);
 TelegramPump();}
void OnChartEvent(const int id,const long &l,const double &d,const string &s){if(id!=CHARTEVENT_OBJECT_CLICK)return;
 if(s=="FS.arm"){
 if(Identity()!=accountIdentity){sessionState.authorized=false;return;}
 if(AutoTrade&&Permissions()&&AccountKind()!="CONTEST"&&!emergencyStop){bool wasAuthorized=sessionState.authorized;criticalFailure=false;RecoverState();sessionState.authorized=!wasAuthorized&&!criticalFailure;Notify("Sessão "+AccountKind()+(sessionState.authorized?" autorizada":" desarmada"));}
 else {Notify("Ativação não concluída: "+EntryBlockDetails(RuntimeEntryBlocks()));}
 ReportSession();
 }
 if(s=="FS.emergency"){emergencyStop=!emergencyStop;sessionState.authorized=false;Notify("Emergência: "+(emergencyStop?"novas entradas bloqueadas; stops mantidos":"desativada; reative manualmente"));}
 if(s=="FS.pause"){entriesPaused=!entriesPaused;ObjectSetString(0,s,OBJPROP_TEXT,entriesPaused?"Retomar entradas":"Pausar entradas");}
 if(s=="FS.status")ReportSession();ObjectSetInteger(0,s,OBJPROP_STATE,false);}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res){
 if(Identity()!=accountIdentity)return;
 if(trans.type!=TRADE_TRANSACTION_DEAL_ADD||!HistoryDealSelect(trans.deal))return;
 long magic=HistoryDealGetInteger(trans.deal,DEAL_MAGIC);long type=HistoryDealGetInteger(trans.deal,DEAL_TYPE);if(type!=DEAL_TYPE_BUY&&type!=DEAL_TYPE_SELL)return;
 long entry=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);double net=HistoryDealGetDouble(trans.deal,DEAL_PROFIT)+HistoryDealGetDouble(trans.deal,DEAL_SWAP)+HistoryDealGetDouble(trans.deal,DEAL_COMMISSION)+HistoryDealGetDouble(trans.deal,DEAL_FEE);
 string origin=magic==(long)MAGIC?"Robô":(magic==0?"Humana":"Outro robô");
 string action=entry==DEAL_ENTRY_IN?"entrada":entry==DEAL_ENTRY_INOUT?"reversão":"saída/parcial";
 string message=origin+" | "+action+" | "+HistoryDealGetString(trans.deal,DEAL_SYMBOL)+" | resultado líquido do negócio "+DoubleToString(net,2);
 message+=" | "+(type==DEAL_TYPE_BUY?"COMPRA":"VENDA")+" | lote "+DoubleToString(HistoryDealGetDouble(trans.deal,DEAL_VOLUME),8)+" | preço "+DoubleToString(HistoryDealGetDouble(trans.deal,DEAL_PRICE),(int)SymbolInfoInteger(HistoryDealGetString(trans.deal,DEAL_SYMBOL),SYMBOL_DIGITS))+" | "+AccountInfoString(ACCOUNT_CURRENCY)+" | negócio "+(string)trans.deal;
 ulong positionID=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
 string dealComment=HistoryDealGetString(trans.deal,DEAL_COMMENT);
 string strategy="LEGACY";if(GlobalVariableCheck(StateKey("q."+(string)positionID)))strategy=PolicyName((int)GlobalVariableGet(StateKey("q."+(string)positionID)));
 if(StringFind(dealComment,"FS2:")==0)strategy=StringSubstr(dealComment,4);
 if(magic!=(long)MAGIC)strategy="EXTERNAL";
 Journal("deal_metrics","strategy="+strategy+"|symbol="+HistoryDealGetString(trans.deal,DEAL_SYMBOL)+"|position="+(string)positionID+"|deal="+(string)trans.deal+"|entry="+(string)entry+"|net="+DoubleToString(net,8)+"|commission="+DoubleToString(HistoryDealGetDouble(trans.deal,DEAL_COMMISSION),8)+"|swap="+DoubleToString(HistoryDealGetDouble(trans.deal,DEAL_SWAP),8));
 if(magic==(long)MAGIC&&entry==DEAL_ENTRY_IN&&StringFind(dealComment,"FS2:")==0){
 GlobalVariableSet(StateKey("q."+(string)positionID),PolicyCode(StringSubstr(dealComment,4)));
 for(int p=0;p<PositionsTotal();p++){if(PositionGetTicket(p)>0&&(ulong)PositionGetInteger(POSITION_IDENTIFIER)==positionID){if(!GlobalVariableCheck(StateKey("r."+(string)positionID)))GlobalVariableSet(StateKey("r."+(string)positionID),MathAbs(PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_SL)));break;}}}
 Journal((string)trans.deal,message+" | commission="+DoubleToString(HistoryDealGetDouble(trans.deal,DEAL_COMMISSION),2)+" | swap="+DoubleToString(HistoryDealGetDouble(trans.deal,DEAL_SWAP),2));Notify(message,strategy);
}
void OnDeinit(const int reason){sessionState.authorized=false;ReleaseLease();ResearchRelease();EventKillTimer();for(int i=0;i<ArraySize(fastHandles);i++){IndicatorRelease(fastHandles[i]);IndicatorRelease(slowHandles[i]);IndicatorRelease(atrHandles[i]);}ObjectDelete(0,"FS.pause");ObjectDelete(0,"FS.status");ObjectDelete(0,"FS.arm");ObjectDelete(0,"FS.emergency");Comment("");}
