#ifndef FOREX_SMART_RISK
#define FOREX_SMART_RISK
bool OwnedPosition(ulong ticket){if(!PositionSelectByTicket(ticket)||PositionGetInteger(POSITION_MAGIC)!=(long)MAGIC)return false;
 if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)return true;
 ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
 if(!HistorySelectByPosition(id))return false;
 // Mixed ownership cannot be safely separated on a netting position.
 for(int i=0;i<HistoryDealsTotal();i++){ulong d=HistoryDealGetTicket(i);long type=HistoryDealGetInteger(d,DEAL_TYPE);if((type==DEAL_TYPE_BUY||type==DEAL_TYPE_SELL)&&HistoryDealGetInteger(d,DEAL_MAGIC)!=(long)MAGIC)return false;}
 return PositionSelectByTicket(ticket);
}
int USDExposure(string s,int direction){if(SymbolInfoString(s,SYMBOL_CURRENCY_BASE)=="USD")return direction;if(SymbolInfoString(s,SYMBOL_CURRENCY_PROFIT)=="USD")return -direction;return 0;}
double AggregateRisk(){double sum=0;
 for(int i=PositionsTotal()-1;i>=0;i--){ulong ticket=PositionGetTicket(i);if(ticket==0)continue;string s=PositionGetString(POSITION_SYMBOL);double sl=PositionGetDouble(POSITION_SL),vol=PositionGetDouble(POSITION_VOLUME);bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;double pnl;
 MqlTick tick;if(!SymbolInfoTick(s,tick)||TimeCurrent()-tick.time>30)return 1e100;
 if(sl<=0||!OrderCalcProfit(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,s,vol,buy?tick.bid:tick.ask,sl,pnl))return 1e100;
 sum+=MathMax(0,-pnl)+CommissionPerLotRoundTurn*vol;}
 // Unknown pending risk is blocked rather than assumed zero.
 if(OrdersTotal()>0)return 1e100;
 return sum;
}
bool ExposureAllowed(string s,int direction){int sign=USDExposure(s,direction),count=0;if(sign==0)return true;
 for(int i=0;i<PositionsTotal();i++){if(PositionGetTicket(i)==0)continue;if(USDExposure(PositionGetString(POSITION_SYMBOL),PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1)==sign)count++;}
 return count<MaxSameUSDPositions;
}
bool NewOrderPlan(string s,bool buy,double entry,double sl,double target,double &lot,double &expected){
 int sessionBlocks=RuntimeEntryBlocks();
 if(sessionBlocks!=0){Reject("Sessão: "+EntryBlockDetails(sessionBlocks));return false;}
 if(LossLimit()){Reject("Limite diário");return false;}
 if(!CommissionEstimateConfirmed){Reject("Confirme comissão estimada da conta nos inputs");return false;}
 if(PositionsTotal()+OrdersTotal()>=2||PositionSelect(s)){Reject("Limite/posição existente");return false;}
 if(!ExposureAllowed(s,buy?1:-1)){Reject("Exposição USD correlacionada");return false;}
 MqlTick tick;double point=SymbolInfoDouble(s,SYMBOL_POINT),tickSize=SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE);
 if(!MathIsValidNumber(entry)||!MathIsValidNumber(sl)||!MathIsValidNumber(target)||entry<=0||sl<=0||target<=0||SymbolInfoDouble(s,SYMBOL_TRADE_CONTRACT_SIZE)<=0||!SymbolInfoTick(s,tick)||point<=0||tickSize<=0||tick.bid<=0||tick.ask<tick.bid||TimeCurrent()-tick.time>30){Reject("Preço/especificações inválidos");return false;}
 long tradeMode=SymbolInfoInteger(s,SYMBOL_TRADE_MODE);if(tradeMode==SYMBOL_TRADE_MODE_DISABLED||tradeMode==SYMBOL_TRADE_MODE_CLOSEONLY||(buy&&tradeMode==SYMBOL_TRADE_MODE_SHORTONLY)||(!buy&&tradeMode==SYMBOL_TRADE_MODE_LONGONLY)){Reject("Direção não permitida pelo símbolo");return false;}
 double distance=MathAbs(entry-sl),spread=tick.ask-tick.bid,loss=0,slip=0;
 double minimum=(SymbolInfoInteger(s,SYMBOL_TRADE_STOPS_LEVEL)+2)*point;
 if((buy&&(sl>=tick.bid-minimum||target<=tick.ask+minimum))||(!buy&&(sl<=tick.ask+minimum||target>=tick.bid-minimum))){Reject("SL/TP inválido para cotação atual");return false;}
 if(distance<=0||spread/distance>MaxSpreadStopRatio){Reject("Spread excessivo em relação ao SL");return false;}
 if(!OrderCalcProfit(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,s,1,entry,sl,loss)||loss>=0||!OrderCalcProfit(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,s,1,entry,entry+(buy?-1:1)*SlippageReservePoints*point,slip)){Reject("Falha de cálculo de risco");return false;}
 if(!MathIsValidNumber(loss)||!MathIsValidNumber(slip)){Reject("Risco não finito");return false;}
 double cost=CommissionPerLotRoundTurn+MathAbs(slip); // spread is already embedded in executable bid/ask prices.
 double spreadCash=0;if(!OrderCalcProfit(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,s,1,entry,entry+(buy?-spread:spread),spreadCash))return false;
 double ratioLimit=MaxCostRiskRatio;if(StrategyMode==MULTISTRATEGY){ResearchConfig config=Config(s);ratioLimit=MathMin(ratioLimit,config.maxCost);}
 if((cost+MathAbs(spreadCash))/MathAbs(loss)>ratioLimit){Reject("Custo/risco excessivo");return false;}
 double perLot=MathAbs(loss)+cost,budget=RiskBudget(RelevantEquity(),RiskPercent);
 lot=Volume(s,MathMin(SymbolInfoDouble(s,SYMBOL_VOLUME_MAX),budget/perLot));expected=lot*perLot;
 if(lot<SymbolInfoDouble(s,SYMBOL_VOLUME_MIN)||lot<=0||expected>budget+1e-8){Reject("Lote mínimo excede risco");return false;}
 lastAggregateRisk=AggregateRisk();if(lastAggregateRisk+expected>RiskBudget(RelevantEquity(),MaxAggregateRiskPercent)){Reject("Risco agregado");return false;}
 double margin;if(!OrderCalcMargin(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,s,lot,entry,margin)||margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE)*0.9){Reject("Margem insuficiente/reserva de 10%");return false;}
 Journal("cost_plan",s+" | "+lastStrategy+" | spread_pts="+DoubleToString(spread/point,1)+" | commission_lot="+DoubleToString(CommissionPerLotRoundTurn,2)+" | slippage_reserve_pts="+(string)SlippageReservePoints+" | risk="+DoubleToString(expected,2)+" | swap_long="+DoubleToString(SymbolInfoDouble(s,SYMBOL_SWAP_LONG),4)+" | swap_short="+DoubleToString(SymbolInfoDouble(s,SYMBOL_SWAP_SHORT),4)+" | swap_mode="+(string)SymbolInfoInteger(s,SYMBOL_SWAP_MODE));
 return true;
}
#endif
