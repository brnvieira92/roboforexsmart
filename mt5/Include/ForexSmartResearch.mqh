#ifndef FOREX_SMART_RESEARCH
#define FOREX_SMART_RESEARCH
struct ResearchHandles {int h50;int h200;int m20;int adx;int bands;int rsi;int atr15;};
ResearchHandles research[];
int PolicyCode(string id){if(id=="EUR_T01")return 1;if(id=="JPY_B01")return 2;if(id=="CHF_R01")return 3;if(id=="GBP_T01")return 4;return 0;}
string PolicyName(int code){if(code==1)return "EUR_T01";if(code==2)return "JPY_B01";if(code==3)return "CHF_R01";if(code==4)return "GBP_T01";return "LEGACY";}
bool SessionRange(string symbol,double &high,double &low){
 MqlDateTime d;TimeToStruct(TimeTradeServer(),d);d.hour=ResearchStartHour;d.min=0;d.sec=0;datetime begin=StructToTime(d),end=begin+RangeBars*300;
 if(TimeTradeServer()<end+300)return false;
 MqlRates bars[];int n=CopyRates(symbol,PERIOD_M5,begin,end-1,bars);if(n!=RangeBars)return false;
 high=bars[0].high;low=bars[0].low;for(int j=1;j<n;j++){high=MathMax(high,bars[j].high);low=MathMin(low,bars[j].low);}return high>low;
}
struct ResearchConfig {bool enabled;double adx;double stopATR;double reward;int spread;double maxCost;};
ResearchConfig Config(string symbol){ResearchConfig c;c.enabled=false;c.adx=20;c.stopATR=1.2;c.reward=2;c.spread=MaxSpreadPoints;c.maxCost=MaxCostRiskRatio;
 if(StringFind(symbol,"EURUSD")==0){c.enabled=EnableEUR_T01;c.adx=EUR_ADX;c.stopATR=EUR_StopATR;c.reward=EUR_RewardR;c.spread=EUR_SpreadPoints;c.maxCost=EUR_CostRatio;}
 else if(StringFind(symbol,"USDJPY")==0){c.enabled=EnableJPY_B01;c.adx=JPY_ADX;c.stopATR=JPY_StopATR;c.reward=JPY_RewardR;c.spread=JPY_SpreadPoints;c.maxCost=JPY_CostRatio;}
 else if(StringFind(symbol,"USDCHF")==0){c.enabled=EnableCHF_R01;c.adx=CHF_ADX;c.stopATR=CHF_StopATR;c.reward=CHF_RewardR;c.spread=CHF_SpreadPoints;c.maxCost=CHF_CostRatio;}
 else if(StringFind(symbol,"GBPUSD")==0){c.enabled=EnableGBP_T01;c.adx=GBP_ADX;c.stopATR=GBP_StopATR;c.reward=GBP_RewardR;c.spread=GBP_SpreadPoints;c.maxCost=GBP_CostRatio;}
 return c;
}
string StrategyID(string s){if(StringFind(s,"EURUSD")==0)return "EUR_T01";if(StringFind(s,"USDJPY")==0)return "JPY_B01";if(StringFind(s,"USDCHF")==0)return "CHF_R01";if(StringFind(s,"GBPUSD")==0)return "GBP_T01";return "UNKNOWN";}
double BufferValue(int h,int buffer,int shift){double b[1];if(CopyBuffer(h,buffer,shift,1,b)!=1)return EMPTY_VALUE;return b[0];}
bool ResearchInit(){int n=ArraySize(symbols);ArrayResize(research,n);
 for(int i=0;i<n;i++){string s=symbols[i];
 research[i].h50=iMA(s,PERIOD_H1,50,0,MODE_EMA,PRICE_CLOSE);research[i].h200=iMA(s,PERIOD_H1,200,0,MODE_EMA,PRICE_CLOSE);
 research[i].m20=iMA(s,PERIOD_M5,20,0,MODE_EMA,PRICE_CLOSE);research[i].adx=iADX(s,PERIOD_M15,14);
 research[i].bands=iBands(s,PERIOD_M5,20,0,2,PRICE_CLOSE);research[i].rsi=iRSI(s,PERIOD_M5,14,PRICE_CLOSE);research[i].atr15=iATR(s,PERIOD_M15,14);
 if(research[i].h50==INVALID_HANDLE||research[i].h200==INVALID_HANDLE||research[i].m20==INVALID_HANDLE||research[i].adx==INVALID_HANDLE||research[i].bands==INVALID_HANDLE||research[i].rsi==INVALID_HANDLE||research[i].atr15==INVALID_HANDLE)return false;
 }return true;
}
void ResearchRelease(){for(int i=0;i<ArraySize(research);i++){IndicatorRelease(research[i].h50);IndicatorRelease(research[i].h200);IndicatorRelease(research[i].m20);IndicatorRelease(research[i].adx);IndicatorRelease(research[i].bands);IndicatorRelease(research[i].rsi);IndicatorRelease(research[i].atr15);}}
// Server-time sessions are explicit settings, never guessed as UTC or Brazilian time.
bool ResearchSession(){MqlDateTime d;TimeToStruct(TimeTradeServer(),d);return d.hour>=ResearchStartHour&&d.hour<ResearchEndHour;}
bool NewsClear(string symbol){
 // Calendar is unavailable/unreliable in tester: research stays closed unless explicitly bypassed.
 if(!UseEconomicCalendar)return AllowResearchWithoutCalendar;
 if(MQLInfoInteger(MQL_TESTER))return AllowResearchWithoutCalendar;
 string currencies[2];currencies[0]=SymbolInfoString(symbol,SYMBOL_CURRENCY_BASE);currencies[1]=SymbolInfoString(symbol,SYMBOL_CURRENCY_PROFIT);
 for(int j=0;j<2;j++){MqlCalendarValue values[];int n=CalendarValueHistory(values,TimeTradeServer()-NewsMinutes*60,TimeTradeServer()+NewsMinutes*60,NULL,currencies[j]);
 if(n<0)return false;for(int k=0;k<n;k++){MqlCalendarEvent e;if(!CalendarEventById(values[k].event_id,e))return false;if(e.importance==CALENDAR_IMPORTANCE_HIGH)return false;}}
 return true;
}
int ResearchSignal(int i,double a,double &stop,double &target){
 string s=symbols[i];ResearchConfig c=Config(s);lastStrategy=StrategyID(s);lastRegime="NO_TRADE";
 if(!c.enabled||!ResearchSession()||!NewsClear(s))return 0;
 double h=Value(research[i].h50,1),hprev=Value(research[i].h50,2),h200=Value(research[i].h200,1),adx=Value(research[i].adx,1),m=Value(research[i].m20,1),baseATR=Value(atr[i],10);
 if(h==EMPTY_VALUE||hprev==EMPTY_VALUE||h200==EMPTY_VALUE||adx==EMPTY_VALUE||m==EMPTY_VALUE||baseATR==EMPTY_VALUE||baseATR<=0)return 0;
 MqlRates r[];ArraySetAsSeries(r,true);if(CopyRates(s,PERIOD_M5,1,RangeBars+3,r)!=RangeBars+3)return 0;
 double hi=r[2].high,lo=r[2].low;for(int k=3;k<RangeBars+2;k++){hi=MathMax(hi,r[k].high);lo=MathMin(lo,r[k].low);}
 if((lastStrategy=="JPY_B01"||lastStrategy=="GBP_T01")&&!SessionRange(s,hi,lo))return 0;
 bool breakout=r[0].close>hi||r[0].close<lo;
 MarketRegime regime=DetectRegime(h,h200,adx,a/baseATR,breakout);lastRegime=EnumToString(regime);
 if(regime==HIGH_VOLATILITY||regime==LOW_VOLATILITY||regime==TRANSITION||regime==NO_TRADE)return 0;
 int direction=0;
 if(lastStrategy=="EUR_T01"&&adx>=c.adx)direction=EURDirection(h,h200,r[1].low,r[1].high,m,r[0].close,r[0].open);
 if(lastStrategy=="JPY_B01"&&adx>=c.adx&&a>baseATR*ATRExpansion)direction=JPYDirection(h,h200,r[0].close,r[0].open,hi,lo,BreakoutATRBuffer*a);
 if(lastStrategy=="GBP_T01"&&adx>=c.adx)direction=GBPDirection(h,h200,r[1].close,r[0].low,r[0].high,r[0].close,r[0].open,hi,lo,BreakoutATRBuffer*a);
 if(lastStrategy=="CHF_R01"&&adx<c.adx&&regime==CONSOLIDATION){double ha=Value(research[i].atr15,1),upper=BufferValue(research[i].bands,1,2),lower=BufferValue(research[i].bands,2,2),u=BufferValue(research[i].bands,1,1),l=BufferValue(research[i].bands,2,1),rsi=Value(research[i].rsi,2);
 if(ha==EMPTY_VALUE||upper==EMPTY_VALUE||lower==EMPTY_VALUE||u==EMPTY_VALUE||l==EMPTY_VALUE||rsi==EMPTY_VALUE||MathAbs(h-hprev)>ha*CHF_FlatATR)return 0;
 direction=CHFDirection(r[1].close,r[0].close,lower,l,upper,u,rsi,CHF_RSI_Low,CHF_RSI_High);}
 if(direction==0)return 0;
 stop=MathMax(c.stopATR*a,direction>0?r[0].close-MathMin(r[0].low,r[1].low):MathMax(r[0].high,r[1].high)-r[0].close);
 target=stop*c.reward;return direction;
}
#endif
