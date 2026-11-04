#property strict
#property version "3.00"
#property description "Forex Smart | uma estrategia ML + price action | modelo validado necessario"
#include <Trade/Trade.mqh>
#include "Include/ForexSmartTelegram.mqh"
#include "Include/ForexSmartMLMath.mqh"
input bool AutoTrade=false;
input double RiskPercent=0.25;
input double ProfitUSD=5.0;
input double DailyLossPercent=2.0;
input double CommissionPerLotRoundTurn=0.0;
input bool TelegramNotifications=true;
const ulong MAGIC=2601027;
const string MODEL_FILE="ForexSmart-ml-model.csv";
string pairs[4]={"EURUSD#","USDJPY#","GBPUSD#","USDCHF#"};
CTrade trade;
bool armed=false,paused=false,emergency=false,fault=false,leased=false;
string scope="",identity="",leaseKey="",mlStatus="Inicializando";double leaseValue=0,dayEquity=0;int dayCode=-1;
datetime scanned[4];
#include "Include/ForexSmartMLRuntime.mqh"
int OnInit(){return MLInit();}
void OnDeinit(const int reason){MLShutdown(reason);}
void OnTimer(){MLTimer();}
void OnChartEvent(const int id,const long &l,const double &d,const string &name){if(id==CHARTEVENT_OBJECT_CLICK)MLClick(name);}
void OnTradeTransaction(const MqlTradeTransaction &t,const MqlTradeRequest &request,const MqlTradeResult &result){MLTransaction(t);}
