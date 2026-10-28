#property strict
#property version "1.10"
#property description "Forex Smart | smartTrade | Demo validation required"
#include <Trade/Trade.mqh>
#include "Include/ForexSmartTelegram.mqh"
input bool AutoTrade=false;
input string Pairs="EURUSD#,USDJPY#,GBPUSD#,USDCHF#";
input double RiskPercent=0.25;
input int MinTPPoints=100;
input int MaxTPPoints=500;
input int MaxSpreadPoints=25;
input double DailyLossPercent=2.0;
input bool PushNotifications=false;
input bool TelegramNotifications=false;
const ulong MAGIC=2601027;
CTrade trade;
string symbols[];
int fast[],slow[],atr[];
datetime lastbar[];
double dayEquity=0;
int dayKey=-1;
bool paused=false;
bool lossNotified=false;
string latest="Inicializando";
void Notify(string text){latest=text; Print(text); Alert(text); if(PushNotifications) SendNotification(text);TelegramQueue("Forex Smart | "+(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO?"DEMO":"REAL/CONTEST")+"\nServidor: "+TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS)+"\n"+text);}
string Key(ulong id){return "FS.partial."+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"."+(string)id;}
double Value(int handle,int shift){double b[1]; if(CopyBuffer(handle,0,shift,1,b)!=1) return EMPTY_VALUE; return b[0];}
void Journal(string type,string detail){
 int f=FileOpen("ForexSmart-history.csv",FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_READ|FILE_ANSI,';',CP_UTF8);
 if(f==INVALID_HANDLE){Print("Journal error: ",GetLastError());return;}
 FileSeek(f,0,SEEK_END); FileWrite(f,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),type,detail); FileFlush(f);FileClose(f);
}
bool Success(){uint r=trade.ResultRetcode();return r==TRADE_RETCODE_DONE||r==TRADE_RETCODE_DONE_PARTIAL;}
void RefreshDay(){MqlDateTime d;TimeToStruct(TimeTradeServer(),d);int key=d.year*1000+d.day_of_year;
 if(key!=dayKey){lossNotified=false;dayKey=key;string k="FS.day."+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"."+(string)key;
 if(GlobalVariableCheck(k))dayEquity=GlobalVariableGet(k);else{dayEquity=AccountInfoDouble(ACCOUNT_EQUITY);GlobalVariableSet(k,dayEquity);}}}
bool LossLimit(){return dayEquity<=0||AccountInfoDouble(ACCOUNT_EQUITY)<=dayEquity*(1-DailyLossPercent/100);}
double Price(string s,double p){double tick=SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE);return NormalizeDouble(MathRound(p/tick)*tick,(int)SymbolInfoInteger(s,SYMBOL_DIGITS));}
double Volume(string s,double v){double step=SymbolInfoDouble(s,SYMBOL_VOLUME_STEP);return NormalizeDouble(MathFloor(v/step+1e-8)*step,8);}
void Manage(){
 for(int p=PositionsTotal()-1;p>=0;p--){ulong ticket=PositionGetTicket(p);if(ticket==0||PositionGetInteger(POSITION_MAGIC)!=(long)MAGIC)continue;
 string s=PositionGetString(POSITION_SYMBOL);int idx=-1;for(int j=0;j<ArraySize(symbols);j++)if(symbols[j]==s)idx=j;if(idx<0)continue;
 double a=Value(atr[idx],1);if(a==EMPTY_VALUE||a<=0)continue;
 bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;MqlTick t;if(!SymbolInfoTick(s,t))continue;
 double current=buy?t.bid:t.ask,entry=PositionGetDouble(POSITION_PRICE_OPEN),gain=(buy?1:-1)*(current-entry);
 double point=SymbolInfoDouble(s,SYMBOL_POINT),old=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
 // Reassess target from current trend strength, bounded relative to entry.
 double f=Value(fast[idx],1),slo=Value(slow[idx],1);
 if(f!=EMPTY_VALUE&&slo!=EMPTY_VALUE){
 double strength=MathMin(1.0,MathAbs(f-slo)/a);
 double targetPoints=MathMax(MinTPPoints,MathMin(MaxTPPoints,a/point*(1+2*strength)));
 double proposed=Price(s,entry+(buy?1:-1)*targetPoints*point);
 double safeDistance=(MathMax(SymbolInfoInteger(s,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(s,SYMBOL_TRADE_FREEZE_LEVEL))+2)*point;
 if(MathAbs(proposed-tp)>a*0.25&&(buy?proposed>t.ask+safeDistance:proposed<t.bid-safeDistance)){
 if(trade.PositionModify(ticket,old,proposed)&&Success())tp=proposed;
 }
 }
 double distance=MathMax(a, (MathMax(SymbolInfoInteger(s,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(s,SYMBOL_TRADE_FREEZE_LEVEL))+2)*point);
 if(gain>=a){double next=Price(s,buy?MathMax(entry,current-distance):MathMin(entry,current+distance));
 if((buy&&(old==0||next>old+point)&&next<t.bid-distance+point)||(!buy&&(old==0||next<old-point)&&next>t.ask+distance-point)){
 if(!trade.PositionModify(ticket,next,tp)||!Success())Print("Trailing rejected: ",trade.ResultRetcodeDescription());
 else if((buy&&old<entry&&next>=entry)||(!buy&&(old==0||old>entry)&&next<=entry))TelegramQueue("Forex Smart | Stop no preço de entrada ou melhor | "+s+" | SL "+DoubleToString(next,(int)SymbolInfoInteger(s,SYMBOL_DIGITS))+" | Custos ainda podem causar perda.");}}
 ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);string key=Key(id);
 if(gain>=1.5*a&&!GlobalVariableCheck(key)){
 double vol=PositionGetDouble(POSITION_VOLUME),part=Volume(s,vol/2),minimum=SymbolInfoDouble(s,SYMBOL_VOLUME_MIN);
 // Partial close is supported only on hedging accounts. Never open an opposite position on netting accounts.
 if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING&&part>=minimum&&vol-part>=minimum){
 if(trade.PositionClosePartial(ticket,part)&&Success()){GlobalVariableSet(key,1);Notify("Parcial: "+s);Journal("partial",s);}}
 }
 }
}
void Scan(int i){
 string s=symbols[i];datetime bar=iTime(s,PERIOD_M5,0);if(bar==0||bar==lastbar[i])return;
 double f=Value(fast[i],1),sl=Value(slow[i],1),a=Value(atr[i],1);if(f==EMPTY_VALUE||sl==EMPTY_VALUE||a==EMPTY_VALUE||a<=0)return;
 MqlRates rates[];ArraySetAsSeries(rates,true);if(CopyRates(s,PERIOD_M5,1,3,rates)!=3)return;
 lastbar[i]=bar;
 bool buy=f>sl&&rates[1].close<=f&&rates[0].close>f;
 bool sell=f<sl&&rates[1].close>=f&&rates[0].close<f;if(!buy&&!sell)return;
 MqlTick tick;if(!SymbolInfoTick(s,tick)||TimeCurrent()-tick.time>30)return;
 double point=SymbolInfoDouble(s,SYMBOL_POINT);if((tick.ask-tick.bid)/point>MaxSpreadPoints)return;
 string side=buy?"COMPRA":"VENDA";Notify("Oportunidade "+side+" "+s);Journal("signal",side+" "+s);
 if(!AutoTrade||paused||LossLimit()||PositionsTotal()>=2||PositionSelect(s)||!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)||!MQLInfoInteger(MQL_TRADE_ALLOWED))return;
 double strength=MathMin(1.0,MathAbs(f-sl)/a);
 double target=MathMax(MinTPPoints,MathMin(MaxTPPoints,a/point*(1+2*strength)))*point;
 double stop=MathMax(1.5*a,(SymbolInfoInteger(s,SYMBOL_TRADE_STOPS_LEVEL)+2)*point);
 if(target<(SymbolInfoInteger(s,SYMBOL_TRADE_STOPS_LEVEL)+2)*point)return;
 double entry=buy?tick.ask:tick.bid,stopPrice=Price(s,entry+(buy?-stop:stop));double loss=0;
 if(!OrderCalcProfit(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,s,1,entry,stopPrice,loss)||loss==0)return;
 double lot=Volume(s,MathMin(SymbolInfoDouble(s,SYMBOL_VOLUME_MAX),AccountInfoDouble(ACCOUNT_EQUITY)*RiskPercent/100/MathAbs(loss)));
 if(lot<SymbolInfoDouble(s,SYMBOL_VOLUME_MIN))return;
 double margin;if(!OrderCalcMargin(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,s,lot,entry,margin)||margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))return;
 trade.SetTypeFillingBySymbol(s);
 bool ok=trade.PositionOpen(s,buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,lot,entry,stopPrice,Price(s,entry+(buy?target:-target)),"Forex Smart");
 if(!ok||!Success()){Print("Entry rejected: ",trade.ResultRetcodeDescription());Journal("reject",s+" "+trade.ResultRetcodeDescription());}
}
void Button(string name,string text,int x){ObjectCreate(0,name,OBJ_BUTTON,0,0,0);ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,name,OBJPROP_YDISTANCE,25);ObjectSetInteger(0,name,OBJPROP_XSIZE,130);ObjectSetString(0,name,OBJPROP_TEXT,text);ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clrDarkGreen);ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);}
int OnInit(){
 if(RiskPercent<=0||RiskPercent>2||MinTPPoints<=0||MaxTPPoints<MinTPPoints||DailyLossPercent<=0||DailyLossPercent>10||MaxSpreadPoints<=0)return INIT_PARAMETERS_INCORRECT;
 int n=StringSplit(Pairs,',',symbols);if(n<1)return INIT_PARAMETERS_INCORRECT;
 ArrayResize(fast,n);ArrayResize(slow,n);ArrayResize(atr,n);ArrayResize(lastbar,n);ArrayInitialize(lastbar,0);
 for(int i=0;i<n;i++){StringTrimLeft(symbols[i]);StringTrimRight(symbols[i]);if(!SymbolSelect(symbols[i],true))return INIT_FAILED;
 fast[i]=iMA(symbols[i],PERIOD_M5,9,0,MODE_EMA,PRICE_CLOSE);slow[i]=iMA(symbols[i],PERIOD_M5,21,0,MODE_EMA,PRICE_CLOSE);atr[i]=iATR(symbols[i],PERIOD_M5,14);
 if(fast[i]==INVALID_HANDLE||slow[i]==INVALID_HANDLE||atr[i]==INVALID_HANDLE)return INIT_FAILED;}
 trade.SetExpertMagicNumber(MAGIC);trade.SetDeviationInPoints(10);RefreshDay();EventSetTimer(2);
 ChartSetInteger(0,CHART_COLOR_BACKGROUND,clrBlack);ChartSetInteger(0,CHART_COLOR_FOREGROUND,clrWhite);ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,clrLime);
 Button("FS.pause","Pausar entradas",15);Button("FS.status","Status",155);
 if(TelegramInit(TelegramNotifications))TelegramQueue("Forex Smart conectado | "+(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO?"DEMO":"REAL/CONTEST")+" | "+(AutoTrade?"Automático":"Alertas")+" | Pares: "+Pairs);
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
void OnTimer(){RefreshDay();
 if(LossLimit()&&!lossNotified){lossNotified=true;Notify("Limite diário atingido: novas entradas bloqueadas; gestão continua.");}Manage();for(int i=0;i<ArraySize(symbols);i++)Scan(i);
 int wins,losses;double net;Metrics(wins,losses,net);
 Comment("smartTrade | FOREX SMART\nModo: ",AutoTrade?"Automático":"Alertas",paused?" | PAUSADO":"",LossLimit()?" | Limite diário":"",
 "\nSaldo: ",DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)," | Equity: ",DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2),
 "\nPosições da conta: ",PositionsTotal()," / 2 | Pares: ",ArraySize(symbols),
 "\nNegócios de saída positivos/negativos: ",wins," / ",losses," | Líquido histórico EA: ",DoubleToString(net,2),
 "\nServidor: ",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS)," | UTC: ",TimeToString(TimeGMT(),TIME_SECONDS),
 "\nTelegram: ",TgReady?"habilitado (ver Experts)":"desativado/indisponível",
 "\n",latest);
 TelegramPump();}
void OnChartEvent(const int id,const long &l,const double &d,const string &s){if(id!=CHARTEVENT_OBJECT_CLICK)return;
 if(s=="FS.pause"){paused=!paused;ObjectSetString(0,s,OBJPROP_TEXT,paused?"Retomar entradas":"Pausar entradas");}
 if(s=="FS.status")Notify("Forex Smart: "+(AutoTrade?"automático":"alertas")+" | posições "+(string)PositionsTotal());ObjectSetInteger(0,s,OBJPROP_STATE,false);}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res){
 if(trans.type!=TRADE_TRANSACTION_DEAL_ADD||!HistoryDealSelect(trans.deal))return;
 long magic=HistoryDealGetInteger(trans.deal,DEAL_MAGIC);long type=HistoryDealGetInteger(trans.deal,DEAL_TYPE);if(type!=DEAL_TYPE_BUY&&type!=DEAL_TYPE_SELL)return;
 long entry=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);double net=HistoryDealGetDouble(trans.deal,DEAL_PROFIT)+HistoryDealGetDouble(trans.deal,DEAL_SWAP)+HistoryDealGetDouble(trans.deal,DEAL_COMMISSION)+HistoryDealGetDouble(trans.deal,DEAL_FEE);
 string origin=magic==(long)MAGIC?"Robô":(magic==0?"Humana":"Outro robô");
 string action=entry==DEAL_ENTRY_IN?"entrada":entry==DEAL_ENTRY_INOUT?"reversão":"saída/parcial";
 string message=origin+" | "+action+" | "+HistoryDealGetString(trans.deal,DEAL_SYMBOL)+" | resultado líquido do negócio "+DoubleToString(net,2);
 message+=" | "+(type==DEAL_TYPE_BUY?"COMPRA":"VENDA")+" | lote "+DoubleToString(HistoryDealGetDouble(trans.deal,DEAL_VOLUME),8)+" | preço "+DoubleToString(HistoryDealGetDouble(trans.deal,DEAL_PRICE),(int)SymbolInfoInteger(HistoryDealGetString(trans.deal,DEAL_SYMBOL),SYMBOL_DIGITS))+" | "+AccountInfoString(ACCOUNT_CURRENCY)+" | negócio "+(string)trans.deal;
 Journal((string)trans.deal,message);Notify(message);
}
void OnDeinit(const int reason){EventKillTimer();for(int i=0;i<ArraySize(fast);i++){IndicatorRelease(fast[i]);IndicatorRelease(slow[i]);IndicatorRelease(atr[i]);}ObjectDelete(0,"FS.pause");ObjectDelete(0,"FS.status");Comment("");}
