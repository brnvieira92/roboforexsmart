#ifndef FOREX_SMART_ML_RUNTIME
#define FOREX_SMART_ML_RUNTIME
#include "ForexSmartMLModel.mqh"
ulong MLFingerprint(string text){ulong value=1469598103934665603;for(int j=0;j<StringLen(text);j++){value^=(ulong)StringGetCharacter(text,j);value*=1099511628211;}return value;}
string MLIdentity(){return (string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+AccountInfoString(ACCOUNT_SERVER)+"|"+(string)AccountInfoInteger(ACCOUNT_TRADE_MODE);}
string MLKey(string text){return "FSML1."+scope+"."+StringFormat("%I64X",MLFingerprint(text));}
string MLKind(){long mode=AccountInfoInteger(ACCOUNT_TRADE_MODE);return mode==ACCOUNT_TRADE_MODE_DEMO?"DEMO":mode==ACCOUNT_TRADE_MODE_REAL?"REAL":"CONTEST";}
bool MLPermissions(){return TerminalInfoInteger(TERMINAL_CONNECTED)&&TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)&&MQLInfoInteger(MQL_TRADE_ALLOWED)&&AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)&&AccountInfoInteger(ACCOUNT_TRADE_EXPERT)&&AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_CONTEST;}
string lastFault="";ulong lastFaultNotice=0;
bool MLJournal(string type,string detail){
 ResetLastError();int f=FileOpen("ForexSmart-"+scope+"-history.csv",FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_READ|FILE_ANSI,';',CP_UTF8);
 int errorCode=GetLastError();string stage="open";bool ok=f!=INVALID_HANDLE;if(ok){stage="seek";ok=FileSeek(f,0,SEEK_END);}if(ok)ok=FileWrite(f,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),type,detail)>0;
 if(f!=INVALID_HANDLE){FileFlush(f);if(GetLastError()!=0)ok=false;FileClose(f);}
 if(!ok){if(GetLastError()!=0)errorCode=GetLastError();fault=true;armed=false;mlStatus="Histórico indisponível ("+stage+", erro "+(string)errorCode+"): sessão desarmada. Feche CSV no Excel e confira disco/acesso.";Print(mlStatus);}return ok;
}
void MLNotice(string text){if(!fault)mlStatus=text;Print(text);TelegramQueue("Forex Smart | "+MLKind()+" | ML_PA_V1\n"+text);}
bool MLLease(){
 if(!leased)return false;double next=(double)TimeLocal()+15;
 if(!GlobalVariableSetOnCondition(leaseKey,next,leaseValue)){leased=false;armed=false;mlStatus="Outra instância/perda de lease";return false;}leaseValue=next;return true;
}
void MLDay(){MqlDateTime d;TimeToStruct(TimeTradeServer(),d);int code=d.year*1000+d.day_of_year;
 if(code==dayCode)return;dayCode=code;string key=MLKey("day"+(string)code);if(GlobalVariableCheck(key))dayEquity=GlobalVariableGet(key);else{dayEquity=AccountInfoDouble(ACCOUNT_EQUITY);GlobalVariableSet(key,dayEquity);}}
bool MLDailyBlocked(){return dayEquity<=0||AccountInfoDouble(ACCOUNT_EQUITY)<=dayEquity*(1-DailyLossPercent/100);}
bool MLEntryAllowed(){return armed&&!paused&&!emergency&&!fault&&AutoTrade&&model.ready&&MLPermissions()&&identity==MLIdentity()&&!MLDailyBlocked();}
struct MLPositionPlan {string symbol;string intent;string modelID;bool buy;bool breached;datetime bar;double entry;double sl;double tp;double initialR;double buffer;double costDistance;double lot;double budget;double riskCash;ulong order;};
string MLPending(string symbol){return "FSML-"+scope+"-pending-"+StringFormat("%I64X",MLFingerprint(symbol))+".csv";}
string MLPositionPath(ulong id){return "FSML-"+scope+"-"+(string)id+".csv";}
bool MLSave(string path,MLPositionPlan &p){
 string tmp=path+".tmp";ResetLastError();int f=FileOpen(tmp,FILE_WRITE|FILE_CSV|FILE_ANSI,';',CP_UTF8);if(f==INVALID_HANDLE)return false;
 bool ok=FileWrite(f,"FSML1",p.symbol,p.intent,p.modelID,(int)p.buy,(long)p.bar,DoubleToString(p.entry,12),DoubleToString(p.sl,12),DoubleToString(p.tp,12),DoubleToString(p.initialR,12),DoubleToString(p.buffer,12),DoubleToString(p.costDistance,12),DoubleToString(p.lot,8),DoubleToString(p.budget,8),DoubleToString(p.riskCash,8),p.order,(int)p.breached)>0;
 FileFlush(f);if(GetLastError()!=0)ok=false;FileClose(f);return ok&&FileMove(tmp,0,path,FILE_REWRITE);
}
bool MLLoad(string path,MLPositionPlan &p){
 ZeroMemory(p);int f=FileOpen(path,FILE_READ|FILE_CSV|FILE_ANSI,';',CP_UTF8);if(f==INVALID_HANDLE)return false;
 string version=FileReadString(f);p.symbol=FileReadString(f);p.intent=FileReadString(f);p.modelID=FileReadString(f);p.buy=StringToInteger(FileReadString(f))!=0;p.bar=(datetime)StringToInteger(FileReadString(f));
 p.entry=StringToDouble(FileReadString(f));p.sl=StringToDouble(FileReadString(f));p.tp=StringToDouble(FileReadString(f));p.initialR=StringToDouble(FileReadString(f));p.buffer=StringToDouble(FileReadString(f));p.costDistance=StringToDouble(FileReadString(f));p.lot=StringToDouble(FileReadString(f));p.budget=StringToDouble(FileReadString(f));p.riskCash=StringToDouble(FileReadString(f));p.order=(ulong)StringToInteger(FileReadString(f));p.breached=StringToInteger(FileReadString(f))!=0;FileClose(f);
 double numbers[9];numbers[0]=p.entry;numbers[1]=p.sl;numbers[2]=p.tp;numbers[3]=p.initialR;numbers[4]=p.buffer;numbers[5]=p.costDistance;numbers[6]=p.lot;numbers[7]=p.budget;numbers[8]=p.riskCash;for(int j=0;j<9;j++)if(!MathIsValidNumber(numbers[j]))return false;
 if(p.buy?(p.sl>=p.entry||p.tp<=p.entry):(p.sl<=p.entry||p.tp>=p.entry))return false;
 return version=="FSML1"&&p.symbol!=""&&p.intent!=""&&p.modelID!=""&&p.bar>0&&p.entry>0&&p.sl>0&&p.tp>0&&p.initialR>0&&MathIsValidNumber(p.initialR)&&p.buffer>0&&p.lot>0&&p.budget>0&&p.riskCash>0&&MathIsValidNumber(p.riskCash)&&p.costDistance>=0&&MathIsValidNumber(p.costDistance);
}
void MLFault(string reason){armed=false;fault=true;mlStatus=reason;if(lastFault!=reason||GetTickCount64()-lastFaultNotice>60000){lastFault=reason;lastFaultNotice=GetTickCount64();MLNotice(reason);MLJournal("ml_fault",reason);}}
bool MLSuccess(){return trade.ResultRetcode()==TRADE_RETCODE_DONE||trade.ResultRetcode()==TRADE_RETCODE_DONE_PARTIAL;}
// Refuse mixed netting ownership; do not manage a human component as if it were ours.
bool MLOwned(ulong ticket){
 if(!PositionSelectByTicket(ticket)||PositionGetInteger(POSITION_MAGIC)!=(long)MAGIC)return false;
 if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)return true;
 ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);if(!HistorySelectByPosition(id))return false;
 for(int j=0;j<HistoryDealsTotal();j++){ulong d=HistoryDealGetTicket(j);long type=HistoryDealGetInteger(d,DEAL_TYPE);if((type==DEAL_TYPE_BUY||type==DEAL_TYPE_SELL)&&HistoryDealGetInteger(d,DEAL_MAGIC)!=(long)MAGIC)return false;}
 return PositionSelectByTicket(ticket);
}
double MLAggregateRisk(){
 if(OrdersTotal()>0)return 1e100;double sum=0;
 for(int j=0;j<PositionsTotal();j++){
 if(PositionGetTicket(j)==0)continue;string symbol=PositionGetString(POSITION_SYMBOL);double sl=PositionGetDouble(POSITION_SL),lot=PositionGetDouble(POSITION_VOLUME),loss=0;bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;MqlTick q;
 if(sl<=0||!SymbolInfoTick(symbol,q)||TimeTradeServer()-q.time>30||!OrderCalcProfit(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,symbol,lot,buy?q.bid:q.ask,sl,loss))return 1e100;
 sum+=MLMax(0,-loss)+CommissionPerLotRoundTurn*lot;
 }return sum;
}
bool MLCapture(ulong deal){
 if(identity!=MLIdentity())return false;
 if(!HistoryDealSelect(deal)||HistoryDealGetInteger(deal,DEAL_MAGIC)!=(long)MAGIC||HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN)return false;
 string symbol=HistoryDealGetString(deal,DEAL_SYMBOL);ulong id=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID),order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);MLPositionPlan p;
 if(MLLoad(MLPositionPath(id),p))return !p.breached;
 if(!MLLoad(MLPending(symbol),p)||p.symbol!=symbol||(p.order!=order&&HistoryDealGetString(deal,DEAL_COMMENT)!=p.intent)){MLFault("Plano ML ausente/incompatível na execução; proteção do servidor preservada");return false;}
 ulong ticket=0;for(int j=0;j<PositionsTotal();j++){ulong t=PositionGetTicket(j);if((ulong)PositionGetInteger(POSITION_IDENTIFIER)==id){ticket=t;break;}}
 if(ticket==0||!MLOwned(ticket)){MLFault("Execução sem posição própria reconciliada");return false;}
 double actual=PositionGetDouble(POSITION_PRICE_OPEN),liveSL=PositionGetDouble(POSITION_SL),liveTP=PositionGetDouble(POSITION_TP),point=SymbolInfoDouble(symbol,SYMBOL_POINT),tick=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE),loss=0;
 bool bad=!MathIsValidNumber(actual)||actual<=0||liveSL<=0||MathAbs(liveSL-p.sl)>tick*.51||MathAbs(liveTP-p.tp)>tick*.51||MathAbs(actual-p.entry)>2*point+1e-12||PositionGetDouble(POSITION_VOLUME)>p.lot+1e-8;
 if(!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,symbol,PositionGetDouble(POSITION_VOLUME),actual,p.sl,loss))bad=true;
 double extra=0;if(!OrderCalcProfit(p.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,symbol,PositionGetDouble(POSITION_VOLUME),actual,actual+(p.buy?-1:1)*4*point,extra))bad=true;
 if(!MathIsValidNumber(loss)||!MathIsValidNumber(extra))bad=true;
 if(MathAbs(loss)+MathAbs(extra)+CommissionPerLotRoundTurn*PositionGetDouble(POSITION_VOLUME)>p.budget+.01)bad=true;
 if(PositionsTotal()+OrdersTotal()>2||MLAggregateRisk()>AccountInfoDouble(ACCOUNT_EQUITY)*MLMin(2*RiskPercent,1)/100)bad=true;
 p.entry=actual;p.initialR=MathAbs(actual-p.sl);p.order=order;p.lot=PositionGetDouble(POSITION_VOLUME);p.riskCash=MathAbs(loss)+MathAbs(extra)+CommissionPerLotRoundTurn*p.lot;
 p.breached=bad;
 if(!MLSave(MLPositionPath(id),p))bad=true;
 if(bad){MLFault("Execução ML fora do plano: sessão desarmada; uma tentativa de fechar a posição afetada");if(MLOwned(ticket)&&MLPermissions())trade.PositionClose(ticket);return false;}
 MLJournal("ml_fill","strategy=ML_PA_V1 | symbol="+symbol+" | position="+(string)id+" | deal="+(string)deal+" | lot="+DoubleToString(p.lot,8));return true;
}
void MLManage(){
 if(!MLPermissions()||identity!=MLIdentity())return;
 for(int j=PositionsTotal()-1;j>=0;j--){ulong ticket=PositionGetTicket(j);if(ticket==0||PositionGetInteger(POSITION_MAGIC)!=(long)MAGIC)continue;
 ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);MLPositionPlan p;
 if(!MLOwned(ticket)){MLFault("Posição netting de propriedade mista: gestão automática suspensa");continue;}
 if(!MLLoad(MLPositionPath(id),p)||p.symbol!=PositionGetString(POSITION_SYMBOL)||p.buy!=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)){MLFault("Plano de posição ML ausente/incompatível; restaurar arquivo antes de gerir");continue;}
 if(p.breached){MLFault("Posição com violação de execução registrada: conferir no terminal");continue;}
 MqlTick q;if(!SymbolInfoTick(p.symbol,q)||TimeTradeServer()-q.time>30)continue;
 int age=iBarShift(p.symbol,PERIOD_M15,p.bar,true);if(age<0){MLFault("Histórico insuficiente para prazo da posição");continue;}
 if(age>=ML_HORIZON){
 string closeKey=MLKey("close"+(string)id);if(GlobalVariableCheck(closeKey)&&GlobalVariableGet(closeKey)>TimeLocal())continue;
 GlobalVariableSet(closeKey,(double)TimeLocal()+15);bool closed=trade.PositionClose(ticket)&&MLSuccess();
 if(closed)MLJournal("ml_time_exit","position="+(string)id+" | symbol="+p.symbol);
 else if(trade.ResultRetcode()==TRADE_RETCODE_TIMEOUT||trade.ResultRetcode()==TRADE_RETCODE_CONNECTION||trade.ResultRetcode()==TRADE_RETCODE_PLACED){GlobalVariableSet(closeKey,(double)TimeLocal()+90*86400);MLFault("Fechamento incerto: reconciliar posição e histórico antes de reativar");}
 continue;}

 datetime bar=iTime(p.symbol,PERIOD_M15,0);string key=MLKey("manage"+(string)id);
 if(GlobalVariableCheck(key)&&GlobalVariableGet(key)==(double)bar)continue;
 MqlRates r[];ArraySetAsSeries(r,true);if(CopyRates(p.symbol,PERIOD_M15,1,1,r)!=1||r[0].time+900!=bar)continue;
 double spread=q.ask-q.bid,mark=r[0].close+(p.buy?0:spread),tick=SymbolInfoDouble(p.symbol,SYMBOL_TRADE_TICK_SIZE),old=PositionGetDouble(POSITION_SL);
 double next=MLTrail(p.buy,p.entry,p.initialR,mark,r[0].low,r[0].high,p.buffer,spread,p.costDistance,old,tick);
 double minimum=(MLMax(SymbolInfoInteger(p.symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(p.symbol,SYMBOL_TRADE_FREEZE_LEVEL))+2)*SymbolInfoDouble(p.symbol,SYMBOL_POINT);
 if((p.buy?next>old+tick*.5&&next<q.bid-minimum:next<old-tick*.5&&next>q.ask+minimum)){
 if(trade.PositionModify(ticket,next,PositionGetDouble(POSITION_TP))&&MLSuccess())MLJournal("ml_trailing","position="+(string)id+" | old="+DoubleToString(old,8)+" | new="+DoubleToString(next,8));
 }
 GlobalVariableSet(key,(double)bar);
 }
}
struct MLCandidate {bool valid;int index;bool buy;datetime bar;double probability;double volatility;double entry;double sl;double tp;double spread;};
bool MLQuote(string symbol,MqlTick &q){return SymbolInfoTick(symbol,q)&&q.bid>0&&q.ask>=q.bid&&TimeTradeServer()-q.time>=0&&TimeTradeServer()-q.time<=10;}
bool MLReadCandidate(int i,MLCandidate &best){
 best.valid=false;string symbol=pairs[i];datetime bar=iTime(symbol,PERIOD_M15,0);if(bar==0||bar==scanned[i])return false;
 MqlRates r[];ArraySetAsSeries(r,true);if(CopyRates(symbol,PERIOD_M15,1,32,r)!=32||r[0].time+900!=bar)return false;
 MqlTick q;if(!MLQuote(symbol,q))return false;scanned[i]=bar;GlobalVariableSet(MLKey("scan"+symbol),(double)bar);
 double o[32],h[32],l[32],c[32];for(int j=0;j<32;j++){o[j]=r[j].open;h[j]=r[j].high;l[j]=r[j].low;c[j]=r[j].close;}
 double tick=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);if(tick<=0)return false;
 for(int side=0;side<2;side++){
 bool buy=side==0;double x[ML_FEATURES],a=0;if(!MLFeatures(o,h,l,c,32,buy,q.ask-q.bid,x,a))continue;
 double probability=MLProbability(x,model.mean,model.scale,model.weights,model.bias,model.calibrationA,model.calibrationB);
 double fraction=MLRiskFraction(probability,model.winLower,model.payoffLower,RiskPercent);
 double entry=buy?q.ask:q.bid,sl=MLInitialStop(buy,h,l,a,q.ask-q.bid,tick),tp=MLTarget(buy,entry,sl,tick);
 MLJournal("ml_score","strategy=ML_PA_V1 | symbol="+symbol+" | side="+(buy?"BUY":"SELL")+" | bar="+(string)(long)bar+" | probability="+DoubleToString(probability,6)+" | Kelly_fraction="+DoubleToString(fraction,8)+" | decision="+(probability<model.probabilityFloor?"BELOW_SCORE":fraction<=0?"NO_KELLY_EDGE":"CANDIDATE")+" | model="+model.id);
 if(probability<model.probabilityFloor||fraction<=0)continue;
 if(!best.valid||probability>best.probability){best.valid=true;best.index=i;best.buy=buy;best.bar=bar;best.probability=probability;best.volatility=a;best.entry=entry;best.sl=sl;best.tp=tp;best.spread=q.ask-q.bid;}
 }return best.valid;
}
void MLReject(string symbol,string reason){MLJournal("reject","ML_PA_V1 | "+symbol+" | "+reason);mlStatus=reason;}
void MLSend(MLCandidate &candidate){
 string symbol=pairs[candidate.index];if(!MLEntryAllowed()||!MLLease())return;
 if(PositionsTotal()+OrdersTotal()>=2||PositionSelect(symbol)){MLReject(symbol,"Posição/limite da conta");return;}
 string dispatch=MLKey("dispatch"+symbol);if(GlobalVariableCheck(dispatch)&&GlobalVariableGet(dispatch)==(double)candidate.bar)return;
 MqlTick q;if(!MLQuote(symbol,q)||iTime(symbol,PERIOD_M15,0)!=candidate.bar)return;
 double point=SymbolInfoDouble(symbol,SYMBOL_POINT),tick=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE),entry=candidate.buy?q.ask:q.bid;
 if(MathAbs(entry-candidate.entry)>2*point+1e-12){MLReject(symbol,"Preço mudou além da reserva; aguardar nova vela");return;}
 double sl=candidate.sl,tp=MLTarget(candidate.buy,entry,sl,tick),minimum=(SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL)+2)*point;
 if(point<=0||sl<=0||tp<=0||(candidate.buy?sl>=q.bid-minimum||tp<=q.ask+minimum:sl<=q.ask+minimum||tp>=q.bid-minimum)){MLReject(symbol,"SL/TP incompatível com corretora/cotação");return;}
 long mode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);if(mode==SYMBOL_TRADE_MODE_DISABLED||mode==SYMBOL_TRADE_MODE_CLOSEONLY||(candidate.buy&&mode==SYMBOL_TRADE_MODE_SHORTONLY)||(!candidate.buy&&mode==SYMBOL_TRADE_MODE_LONGONLY))return;
 double loss=0,win=0,slip=0,tickCash=0;
 if(!OrderCalcProfit(candidate.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,symbol,1,entry,sl,loss)||!OrderCalcProfit(candidate.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,symbol,1,entry,tp,win)||!OrderCalcProfit(candidate.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,symbol,1,entry,entry+(candidate.buy?-1:1)*4*point,slip)||!OrderCalcProfit(candidate.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,symbol,1,entry,entry+(candidate.buy?tick:-tick),tickCash))return;
 double costs=CommissionPerLotRoundTurn+MathAbs(slip),perLoss=MathAbs(loss)+costs,perWin=win-costs;
 if(loss>=0||perWin<=0||!MathIsValidNumber(perLoss)||!MathIsValidNumber(perWin)||candidate.probability*perWin-(1-candidate.probability)*perLoss<=0){MLReject(symbol,"Economia líquida não positiva após custos");return;}
 double fraction=MLRiskFraction(candidate.probability,model.winLower,model.payoffLower,RiskPercent),budget=AccountInfoDouble(ACCOUNT_EQUITY)*fraction;
 double step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP),minimumLot=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN),maximumLot=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
 if(step<=0||minimumLot<=0||maximumLot<minimumLot){MLReject(symbol,"Especificação de volume inválida");return;}
 double lot=MLVolume(MLMin(budget/perLoss,ProfitUSD/perWin),step,maximumLot);
 if(lot<minimumLot&&minimumLot*perLoss<=budget&&minimumLot*perWin<=10)lot=minimumLot;
 double risk=lot*perLoss,gain=lot*perWin,margin=0;
 if(lot<minimumLot||lot<=0||risk>budget+1e-8){MLReject(symbol,"Lote mínimo acima do risco Kelly/limite");return;}
 if(MLAggregateRisk()+risk>AccountInfoDouble(ACCOUNT_EQUITY)*MLMin(2*RiskPercent,1)/100){MLReject(symbol,"Risco agregado/posição manual sem SL");return;}
 if(!OrderCalcMargin(candidate.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,symbol,lot,entry,margin)||margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE)*.9){MLReject(symbol,"Margem insuficiente com reserva de 10%");return;}
 MLPositionPlan p;p.symbol=symbol;p.intent="FSML1:"+(string)(long)candidate.bar;p.modelID=model.id;p.buy=candidate.buy;p.bar=candidate.bar;p.entry=entry;p.sl=sl;p.tp=tp;p.initialR=MathAbs(entry-sl);p.buffer=MLMax(.1*candidate.volatility,candidate.spread);p.costDistance=MathAbs(tickCash)>0?costs/MathAbs(tickCash)*tick:0;p.lot=lot;p.budget=budget;p.riskCash=risk;p.order=0;p.breached=false;
 if(!MLSave(MLPending(symbol),p)){MLFault("Falha persistindo plano pré-envio");return;}
 if(!MLJournal("ml_plan","strategy=ML_PA_V1 | symbol="+symbol+" | probability="+DoubleToString(candidate.probability,6)+" | Kelly_fraction="+DoubleToString(fraction,8)+" | lot="+DoubleToString(lot,8)+" | entry="+DoubleToString(entry,8)+" | SL="+DoubleToString(sl,8)+" | TP="+DoubleToString(tp,8)+" | risk="+DoubleToString(risk,4)+" | estimated_net="+DoubleToString(gain,4)+" | model="+model.id))return;
 MqlTick finalQuote;if(!MLQuote(symbol,finalQuote)||MathAbs((candidate.buy?finalQuote.ask:finalQuote.bid)-entry)>2*point+1e-12||finalQuote.ask-finalQuote.bid>q.ask-q.bid+point||!MLEntryAllowed())return;
 if(GlobalVariableSet(dispatch,(double)candidate.bar)==0){MLFault("Falha persistindo idempotência");return;}GlobalVariablesFlush();
 if(!MLEntryAllowed()||!MLLease())return;
 trade.SetTypeFillingBySymbol(symbol);bool ok=trade.PositionOpen(symbol,candidate.buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,lot,entry,sl,tp,p.intent);
 p.order=trade.ResultOrder();if(!MLSave(MLPending(symbol),p))MLFault("Falha persistindo ordem enviada");
 uint retcode=trade.ResultRetcode();MLJournal("order_dispatch","strategy=ML_PA_V1 | symbol="+symbol+" | retcode="+(string)retcode);
 if(retcode==TRADE_RETCODE_PLACED||retcode==TRADE_RETCODE_TIMEOUT||retcode==TRADE_RETCODE_CONNECTION){MLFault("Resposta de ordem incerta: reconciliar antes de reativar; não será reenviada");return;}
 if(ok&&MLSuccess()){ulong deal=trade.ResultDeal();if(MLCapture(deal))MLNotice("Entrada automática "+(candidate.buy?"COMPRA ":"VENDA ")+symbol+" | estimativa líquida USD "+DoubleToString(gain,2));}
 else MLReject(symbol,trade.ResultRetcodeDescription());
}
void MLButton(string name,string text,int x,int width=130){ObjectCreate(0,name,OBJ_BUTTON,0,0,0);ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,name,OBJPROP_YDISTANCE,25);ObjectSetInteger(0,name,OBJPROP_XSIZE,width);ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clrDarkGreen);ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);ObjectSetString(0,name,OBJPROP_TEXT,text);}
int MLInit(){
 if(RiskPercent<=0||RiskPercent>1||ProfitUSD<3||ProfitUSD>10||DailyLossPercent<=0||DailyLossPercent>5||CommissionPerLotRoundTurn<0||!MathIsValidNumber(RiskPercent)||!MathIsValidNumber(ProfitUSD)||!MathIsValidNumber(DailyLossPercent)||!MathIsValidNumber(CommissionPerLotRoundTurn)||AccountInfoString(ACCOUNT_CURRENCY)!="USD")return INIT_PARAMETERS_INCORRECT;
 identity=MLIdentity();scope=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"."+StringFormat("%I64X",MLFingerprint(AccountInfoString(ACCOUNT_SERVER)));leaseKey="FS2."+scope+".lease";
 GlobalVariableTemp(leaseKey);double old=GlobalVariableGet(leaseKey);if(old>TimeLocal()){Print("Outra instância já administra esta conta");return INIT_FAILED;}leaseValue=(double)TimeLocal()+15;leased=GlobalVariableSetOnCondition(leaseKey,leaseValue,old);if(!leased)return INIT_FAILED;
 for(int j=0;j<PositionsTotal();j++){if(PositionGetTicket(j)>0&&PositionGetInteger(POSITION_MAGIC)==(long)MAGIC&&StringFind(PositionGetString(POSITION_COMMENT),"FSML1:")!=0){Print("Posição de versão anterior aberta: restaure v2.16 ou instale v3 somente sem posições antigas");return INIT_FAILED;}}
 for(int j=0;j<4;j++){if(!SymbolSelect(pairs[j],true))return INIT_FAILED;string key=MLKey("scan"+pairs[j]);scanned[j]=GlobalVariableCheck(key)?(datetime)GlobalVariableGet(key):0;}
 trade.SetExpertMagicNumber(MAGIC);trade.SetDeviationInPoints(2);MLDay();MLLoadModel();TelegramInit(TelegramNotifications);EventSetTimer(2);
 if(MQLInfoInteger(MQL_TESTER)&&AutoTrade&&model.ready&&!fault){armed=true;MLJournal("ml_session","AUTHORIZED | reason=tester_explicit_AutoTrade");}
 ChartSetInteger(0,CHART_COLOR_BACKGROUND,clrBlack);ChartSetInteger(0,CHART_COLOR_FOREGROUND,clrWhite);
 MLButton("FS.pause","Pausar",15);MLButton("FS.status","Carregar modelo",155);MLButton("FS.arm","ATIVAR "+MLKind(),295);MLButton("FS.emergency","EMERGÊNCIA",435);
 MLJournal("ml_init","strategy=ML_PA_V1 | model_ready="+(string)(int)model.ready+" | session=DISARMED | six_inputs=1 | status="+mlStatus);return INIT_SUCCEEDED;
}
void MLShutdown(int reason){armed=false;if(leased)GlobalVariableSetOnCondition(leaseKey,0,leaseValue);leased=false;EventKillTimer();ObjectDelete(0,"FS.pause");ObjectDelete(0,"FS.status");ObjectDelete(0,"FS.arm");ObjectDelete(0,"FS.emergency");Comment("");}
void MLTimer(){
 if(identity!=MLIdentity()){armed=false;fault=true;mlStatus="Conta alterada: reanexe o robô";return;}
 if(!MLLease())return;if(armed&&!MLPermissions()){armed=false;MLJournal("ml_session","DISARMED | reason=connection_or_trade_permission_lost");mlStatus="Permissão/conexão perdida: reativação manual necessária";}
 if(model.ready&&(TimeTradeServer()<model.evaluationEnd||TimeTradeServer()-model.evaluationEnd>90*86400)){model.ready=false;armed=false;mlStatus="Modelo fora da validade temporal";}
 MLDay();MLManage();
 if(model.ready){MLCandidate candidates[4];for(int i=0;i<4;i++)MLReadCandidate(i,candidates[i]);
 for(int rank=0;rank<2;rank++){int best=-1;for(int i=0;i<4;i++)if(candidates[i].valid&&(best<0||candidates[i].probability>candidates[best].probability))best=i;if(best<0)break;
 if(MLEntryAllowed())MLSend(candidates[best]);else if(!AutoTrade)TelegramQueue("Forex Smart | Sinal ML em avaliação "+pairs[best]+" | probabilidade estimada "+DoubleToString(candidates[best].probability,3));candidates[best].valid=false;}}
 ObjectSetString(0,"FS.arm",OBJPROP_TEXT,(armed?"DESARMAR ":"ATIVAR ")+MLKind());
 Comment("FOREX SMART 3.00 | ML + PRICE ACTION | ",MLKind(),"\nSessão: ",armed?"AUTORIZADA":"DESARMADA",fault?" | FALHA: conferir Experts":"",paused?" | PAUSADO":"",emergency?" | EMERGÊNCIA":"","\nModelo: ",model.ready?model.id:"NÃO DISPONÍVEL","\nSaldo USD: ",DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)," | Equity: ",DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2),"\nPosições: ",PositionsTotal(),"/2 | Objetivo aproximado USD: ",DoubleToString(ProfitUSD,2),"\nRisco máximo: ",DoubleToString(RiskPercent,2),"% | Kelly 1/4 | M15 | ",MLDailyBlocked()?"LIMITE DIÁRIO":"","\n",mlStatus);TelegramPump();
}
void MLClick(string name){
 if(name=="FS.pause"){armed=false;paused=!paused;ObjectSetString(0,"FS.pause",OBJPROP_TEXT,paused?"Retomar":"Pausar");MLJournal("ml_session","DISARMED | pause="+(string)(int)paused);}
 if(name=="FS.emergency"){armed=false;emergency=!emergency;MLJournal("ml_session","DISARMED | emergency="+(string)(int)emergency);}
 if(name=="FS.status"){armed=false;MLLoadModel();MLJournal("ml_session","DISARMED | model_reload="+(string)(int)model.ready);}
 if(name=="FS.arm"){
 if(armed){armed=false;MLJournal("ml_session","DISARMED | reason=manual");}
 else if(AutoTrade&&!paused&&!emergency&&model.ready&&MLPermissions()&&!MLDailyBlocked()&&identity==MLIdentity()){
 if(MLJournal("ml_session_probe","manual activation")){fault=false;lastFault="";bool recovered=true;
 for(int j=0;j<PositionsTotal();j++){ulong ticket=PositionGetTicket(j);if(ticket>0&&PositionGetInteger(POSITION_MAGIC)==(long)MAGIC){MLPositionPlan p;ulong positionID=(ulong)PositionGetInteger(POSITION_IDENTIFIER);if(!MLOwned(ticket)||!MLLoad(MLPositionPath(positionID),p)||p.breached||!HistorySelectByPosition(positionID))recovered=false;}}
 if(recovered&&OrdersTotal()==0&&MLLease()){for(int j=0;j<PositionsTotal();j++){if(PositionGetTicket(j)>0&&PositionGetInteger(POSITION_MAGIC)==(long)MAGIC)GlobalVariableDel(MLKey("close"+(string)PositionGetInteger(POSITION_IDENTIFIER)));}armed=true;if(MLJournal("ml_session","AUTHORIZED | reason=manual"))MLNotice("Sessão autorizada | ML_PA_V1");}else MLFault("Posição própria não reconciliada");
 }}else MLNotice("Ativação pendente: modelo, AutoTrade, permissões, pausa/emergência ou limite diário");
 }ObjectSetInteger(0,name,OBJPROP_STATE,false);
}
void MLTransaction(const MqlTradeTransaction &t){
 if(identity!=MLIdentity()||t.type!=TRADE_TRANSACTION_DEAL_ADD||!HistoryDealSelect(t.deal))return;
 long type=HistoryDealGetInteger(t.deal,DEAL_TYPE);if(type!=DEAL_TYPE_BUY&&type!=DEAL_TYPE_SELL)return;
 long entryType=HistoryDealGetInteger(t.deal,DEAL_ENTRY);string symbol=HistoryDealGetString(t.deal,DEAL_SYMBOL);bool robot=HistoryDealGetInteger(t.deal,DEAL_MAGIC)==(long)MAGIC;
 if(robot&&entryType==DEAL_ENTRY_IN)MLCapture(t.deal);if(!HistoryDealSelect(t.deal))return;
 double commission=HistoryDealGetDouble(t.deal,DEAL_COMMISSION)+HistoryDealGetDouble(t.deal,DEAL_FEE),swap=HistoryDealGetDouble(t.deal,DEAL_SWAP),net=HistoryDealGetDouble(t.deal,DEAL_PROFIT)+commission+swap;
 ulong position=(ulong)HistoryDealGetInteger(t.deal,DEAL_POSITION_ID);MLPositionPlan saved;bool tracked=MLLoad(MLPositionPath(position),saved);
 MLJournal("deal_metrics","strategy="+(tracked?"ML_PA_V1":robot?"ML_UNRECONCILED":"EXTERNAL")+"|symbol="+symbol+"|position="+(string)position+"|deal="+(string)t.deal+"|entry="+(string)entryType+"|net="+DoubleToString(net,8)+"|commission="+DoubleToString(commission,8)+"|swap="+DoubleToString(swap,8));
 bool stillOpen=false;double totalResult=net;
 if(entryType!=DEAL_ENTRY_IN){
 for(int j=0;j<PositionsTotal();j++){if(PositionGetTicket(j)>0&&(ulong)PositionGetInteger(POSITION_IDENTIFIER)==position)stillOpen=true;}
 if(!HistorySelectByPosition(position)){MLFault("Histórico da posição indisponível: saída não consolidada");return;}
 {totalResult=0;for(int j=0;j<HistoryDealsTotal();j++){ulong d=HistoryDealGetTicket(j);totalResult+=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_FEE);}}
 if(tracked)MLJournal("plan_exit","strategy=ML_PA_V1 | symbol="+symbol+" | position="+(string)position+" | deal="+(string)t.deal+" | official_reason="+EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(t.deal,DEAL_REASON))+" | fully_closed="+(string)(int)!stillOpen+" | cumulative_net="+DoubleToString(totalResult,8)+" | net_R="+DoubleToString(totalResult/saved.riskCash,8)+" | duration_seconds="+(string)(long)(TimeTradeServer()-saved.bar)+" | regime=ML | server_open_hour="+(string)((saved.bar/3600)%24));
 }
 string action=entryType==DEAL_ENTRY_IN?"entrada":stillOpen?"saída parcial":totalResult>0?"GANHO":totalResult<0?"PERDA":"ZERO";
 MLNotice((robot?"Robô":"Humana")+" | "+action+" | "+symbol+" | líquido acumulado USD "+DoubleToString(totalResult,2));
}
#endif
