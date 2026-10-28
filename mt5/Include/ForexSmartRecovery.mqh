#ifndef FOREX_SMART_RECOVERY
#define FOREX_SMART_RECOVERY
void RecoverState(){
 // Enumerate actual positions, not just configured entry pairs. Account history supplies scoped evidence.
 for(int p=PositionsTotal()-1;p>=0;p--){ulong ticket=PositionGetTicket(p);if(ticket==0||PositionGetInteger(POSITION_MAGIC)!=(long)MAGIC)continue;
 string symbol=PositionGetString(POSITION_SYMBOL);ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);bool found=false;
 for(int i=0;i<ArraySize(symbols);i++)if(symbols[i]==symbol)found=true;
 if(!found){int n=ArraySize(symbols);ArrayResize(symbols,n+1);ArrayResize(fast,n+1);ArrayResize(slow,n+1);ArrayResize(atr,n+1);ArrayResize(lastbar,n+1);
 symbols[n]=symbol;SymbolSelect(symbol,true);fast[n]=iMA(symbol,PERIOD_M5,9,0,MODE_EMA,PRICE_CLOSE);slow[n]=iMA(symbol,PERIOD_M5,21,0,MODE_EMA,PRICE_CLOSE);atr[n]=iATR(symbol,PERIOD_M5,14);lastbar[n]=iTime(symbol,PERIOD_M5,0);
 if(StrategyMode==MULTISTRATEGY){ResearchRelease();if(!ResearchInit())criticalFailure=true;}
 }
 if(!HistorySelectByPosition(id)){criticalFailure=true;Journal("recovery","History unavailable; entries blocked");continue;}
 bool exited=false;double initialR=0;string policy="LEGACY";
 for(int j=0;j<HistoryDealsTotal();j++){ulong d=HistoryDealGetTicket(j);long type=HistoryDealGetInteger(d,DEAL_TYPE);if(type!=DEAL_TYPE_BUY&&type!=DEAL_TYPE_SELL)continue;
 long entry=HistoryDealGetInteger(d,DEAL_ENTRY);
 if(entry==DEAL_ENTRY_OUT||entry==DEAL_ENTRY_OUT_BY||entry==DEAL_ENTRY_INOUT)exited=true;
 if(entry==DEAL_ENTRY_IN&&initialR==0&&HistoryDealGetInteger(d,DEAL_MAGIC)==(long)MAGIC){double stop=HistoryDealGetDouble(d,DEAL_SL);if(stop>0)initialR=MathAbs(HistoryDealGetDouble(d,DEAL_PRICE)-stop);string c=HistoryDealGetString(d,DEAL_COMMENT);if(StringFind(c,"FS2:")==0)policy=StringSubstr(c,4);}
 }
 // v1.10 globals lacked server identity. Do NOT blindly import them across servers.
 // Verified exit on the current account position is safe evidence to avoid a second partial.
 if(exited)GlobalVariableSet(Key(id),1);
 if(initialR>0&&!GlobalVariableCheck(StateKey("r."+(string)id)))GlobalVariableSet(StateKey("r."+(string)id),initialR);
 if(policy!="LEGACY")GlobalVariableSet(StateKey("q."+(string)id),PolicyCode(policy));
 Journal("recovery",symbol+" | position="+(string)id+" | policy="+policy+" | prior_exit="+(string)exited);
 }
 GlobalVariablesFlush();
}
#endif
