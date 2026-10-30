#ifndef FOREX_SMART_CORE
#define FOREX_SMART_CORE
// Platform-independent policies, also compiled by the native regression harness.
enum StrategySelection { LEGACY=0, MULTISTRATEGY=1 };
enum MarketRegime { NO_TRADE=0, TREND_UP, TREND_DOWN, CONSOLIDATION, HIGH_VOLATILITY, LOW_VOLATILITY, BREAKOUT, TRANSITION };
struct SessionState {bool identified;long login;long server;int kind;bool authorized;};
bool ObserveAccount(SessionState &state,long login,long server,int kind){
 bool changed=!state.identified||state.login!=login||state.server!=server||state.kind!=kind;
 if(changed){state.identified=true;state.login=login;state.server=server;state.kind=kind;state.authorized=false;}
 return changed;
}
void ApplyJournalResult(SessionState &state,bool &critical,bool success){
 if(!success){state.authorized=false;critical=true;}
 // A successful retry does not restore authorization or clear an unrelated critical fault.
}
double LegacyStop(double atr){return 1.5*atr;}
double FSMin(double a,double b){return a<b?a:b;}
double FSMax(double a,double b){return a>b?a:b;}
double FSAbs(double a){return a<0?-a:a;}
int LegacyDirection(double fast,double slow,double priorClose,double close){
 if(fast>slow&&priorClose<=fast&&close>fast)return 1;
 if(fast<slow&&priorClose>=fast&&close<fast)return -1;
 return 0;
}
double LegacyTarget(double atr,double point,double fast,double slow,int minimum,int maximum){
 if(atr<=0||point<=0)return 0;
 double strength=FSMin(1,FSAbs(fast-slow)/atr);
 return FSMax(minimum,FSMin(maximum,atr/point*(1+2*strength)))*point;
}
bool SessionPermitted(bool autoTrade,bool authorized,bool paused,bool emergency,bool connected,bool allowed,bool contest){
 return autoTrade&&authorized&&!paused&&!emergency&&connected&&allowed&&!contest;
}
enum EntryBlock {
 BLOCK_AUTO=1, BLOCK_AUTH=2, BLOCK_PAUSED=4, BLOCK_EMERGENCY=8,
 BLOCK_CONNECTION=16, BLOCK_TERMINAL=32, BLOCK_EA=64,
 BLOCK_ACCOUNT=128, BLOCK_EXPERT=256, BLOCK_CONTEST=512, BLOCK_CRITICAL=1024
};
int EntryBlocks(bool autoTrade,bool authorized,bool paused,bool emergency,bool connected,
                bool terminalAllowed,bool eaAllowed,bool accountAllowed,bool expertAllowed,bool contest,bool critical){
 int mask=0;
 if(!autoTrade)mask|=BLOCK_AUTO;
 if(!authorized)mask|=BLOCK_AUTH;
 if(paused)mask|=BLOCK_PAUSED;
 if(emergency)mask|=BLOCK_EMERGENCY;
 if(!connected)mask|=BLOCK_CONNECTION;
 if(!terminalAllowed)mask|=BLOCK_TERMINAL;
 if(!eaAllowed)mask|=BLOCK_EA;
 if(!accountAllowed)mask|=BLOCK_ACCOUNT;
 if(!expertAllowed)mask|=BLOCK_EXPERT;
 if(contest)mask|=BLOCK_CONTEST;
 if(critical)mask|=BLOCK_CRITICAL;
 return mask;
}
double FloorVolume(double requested,double step,double maximum){
 if(step<=0||requested<=0||maximum<=0)return 0;
 return MathFloor(FSMin(requested,maximum)/step)*step;
}
double ReferenceEquity(double actual,double baseline,double reference,double cashflows){return FSMin(actual,reference+actual-baseline-cashflows);}
double RiskBudget(double equity,double percent){return equity>0&&percent>0?equity*percent/100:0;}
bool DailyBlocked(double equity,double reference,double percent){return reference<=0||equity<=reference*(1-percent/100);}
bool StopImproves(bool buy,double oldStop,double proposed,double point){return buy?(oldStop==0||proposed>oldStop+point):(oldStop==0||proposed<oldStop-point);}
double TrailingCandidate(bool buy,double entry,double current,double distance){return buy?FSMax(entry,current-distance):FSMin(entry,current+distance);}
int EURDirection(double h,double h200,double priorLow,double priorHigh,double ema,double close,double open){
 if(h>h200&&priorLow<=ema&&close>ema&&close>open)return 1;
 if(h<h200&&priorHigh>=ema&&close<ema&&close<open)return -1;
 return 0;
}
int JPYDirection(double h,double h200,double close,double open,double high,double low,double buffer){
 if(h>h200&&close>high+buffer&&close>open)return 1;
 if(h<h200&&close<low-buffer&&close<open)return -1;
 return 0;
}
int GBPDirection(double h,double h200,double priorClose,double low,double high,double close,double open,double rangeHigh,double rangeLow,double buffer){
 if(h>h200&&priorClose>rangeHigh&&low<=rangeHigh+buffer&&close>rangeHigh&&close>open)return 1;
 if(h<h200&&priorClose<rangeLow&&high>=rangeLow-buffer&&close<rangeLow&&close<open)return -1;
 return 0;
}
int CHFDirection(double priorClose,double close,double priorLower,double lower,double priorUpper,double upper,double rsi,double rsiLow,double rsiHigh){
 if(priorClose<priorLower&&close>lower&&rsi<rsiLow)return 1;
 if(priorClose>priorUpper&&close<upper&&rsi>rsiHigh)return -1;
 return 0;
}
MarketRegime DetectRegime(double ema50,double ema200,double adx,double atrRatio,bool breakout){
 if(atrRatio<=0)return NO_TRADE;
 if(atrRatio>2.5)return HIGH_VOLATILITY;
 if(atrRatio<0.55)return LOW_VOLATILITY;
 if(breakout&&adx>=20)return BREAKOUT;
 if(adx<18)return CONSOLIDATION;
 if(adx<20)return TRANSITION;
 if(ema50>ema200)return TREND_UP;
 if(ema50<ema200)return TREND_DOWN;
 return NO_TRADE;
}
#endif
