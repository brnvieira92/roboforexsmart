#include <cassert>
#include <cmath>
#include <iostream>
#define MathFloor std::floor
#include "../../mt5/Include/ForexSmartCore.mqh"
#include "../../mt5/Include/ForexSmartPlanMath.mqh"
int main(){
 // Original approved EUR sell: spread can increase 1 -> 1.1 pip, still within economic gates.
 assert(QuoteWithinSendPolicy(1.12144,1.12143,1.12143,1.12154,1,10,.0001,1,.00001,25));
 assert(!QuoteWithinSendPolicy(1.12144,1.12120,1.12120,1.12130,1,10,.0001,1,.00001,25));
 assert(!QuoteWithinSendPolicy(1.12144,1.12143,1.12143,1.12169,1,10,.0001,1,.00001,25));
 assert(!QuoteWithinSendPolicy(1.12144,1.12143,1.12143,1.12154,11,10,.0001,1,.00001,25));
 assert(!QuoteWithinSendPolicy(1.12144,1.12143,1.12143,1.12154,-1,10,.0001,1,.00001,25));
 // 23.1-pip stop / 4.574-pip ATR = 5.05 ATR: adaptive policy accepts geometry, never guarantees RR.
 double distance=.00231,atrValue=.0004574;
 assert(distance>StopDistanceCap(FIXED_PIP_LIMIT,20,atrValue,6,.0001,60));
 assert(distance<StopDistanceCap(ATR_WITH_ABSOLUTE_CAP,20,atrValue,6,.0001,60));
 assert(StopDistanceCap(ATR_WITH_ABSOLUTE_CAP,20,.002,6,.0001,60)==.006);
 assert(distance>StopDistanceCap(ATR_WITH_ABSOLUTE_CAP,20,.0002,6,.0001,60));
 // Wider stop reduces volume under the same monetary budget, unchanged commission/slippage.
 assert(CostedVolume(24.24,231,2,.01,100)<CostedVolume(24.24,200,2,.01,100));
 int run=0;
 // Wicks do not break support. Two new closed candles are required; then a later retest.
 assert(ClosedWaitEvent(WAIT_BREAKOUT,false,0,1.12,.0001,.0001,2,run,0,0,1.121,1.1201,1.119,1.122)==0&&run==0);
 assert(ClosedWaitEvent(WAIT_BREAKOUT,false,0,1.12,.0001,.0001,2,run,0,0,1.1201,1.1198,1.1197,1.1202)==0&&run==1);
 assert(ClosedWaitEvent(WAIT_BREAKOUT,false,0,1.12,.0001,.0001,2,run,0,0,1.1198,1.1197,1.1195,1.1199)==1&&run==2);
 assert(ClosedWaitEvent(WAIT_RETEST,false,0,1.12,.0001,.0001,2,run,0,0,1.1199,1.1196,1.1195,1.12005)==2);
 assert(ClosedWaitEvent(WAIT_RETEST,false,0,1.12,.0001,.0001,2,run,0,0,1.1199,1.1202,1.1195,1.1203)==3);
 // Breakout count resets on an intervening close back inside; bullish side is symmetric.
 run=1;assert(ClosedWaitEvent(WAIT_BREAKOUT,true,0,1.12,.0001,.0001,2,run,0,0,1.12,1.1199,1.1198,1.1202)==0&&run==0);
 assert(ClosedWaitEvent(WAIT_BREAKOUT,true,0,1.12,.0001,.0001,2,run,0,0,1.12,1.1202,1.1198,1.1203)==0&&run==1);
 assert(ClosedWaitEvent(WAIT_BREAKOUT,true,0,1.12,.0001,.0001,2,run,0,0,1.1202,1.1203,1.12,1.1204)==1);
 assert(ClosedWaitEvent(WAIT_RETEST,true,0,1.12,.0001,.0001,2,run,0,0,1.1201,1.1203,1.12005,1.1204)==2);
 // Frozen EMA zone touched, followed by a CLOSED continuation candle; no pursuit without touch.
 assert(ClosedWaitEvent(WAIT_PULLBACK,true,1.12,0,.0002,.0001,2,run,1.1199,1.1202,1.1201,1.1205,1.1201,1.1206)==2);
 assert(ClosedWaitEvent(WAIT_PULLBACK,true,1.12,0,.0002,.0001,2,run,1.121,1.1212,1.1211,1.1215,1.1211,1.1216)==0);
 assert(!OpportunityExpired(2,3));assert(OpportunityExpired(3,3));assert(OpportunityExpired(-1,3));
 assert(ObstacleQualified(UNBROKEN_CONFIRMED_PIVOTS,1,0,2,3,false,false));
 assert(!ObstacleQualified(UNBROKEN_CONFIRMED_PIVOTS,3,5,2,3,true,true));
 // Real exit policy: a 3R full target with half at 1.5R projects 2.25R gross, before total costs.
 double projected=ProjectedGrossWin(261,130.5,.27,.13)-2*.27;
 assert(std::abs(projected/24.03-2.204119850187266)<1e-9);
 // OHLC ambiguity never yields a retrospective winner from the entry candle.
 assert(CounterfactualBarDecision(true,true,.99,1.03,1.,1.02,false)==CF_ENTRY_AMBIGUOUS);
 assert(CounterfactualBarDecision(true,false,.99,1.03,1.,1.02,false)==CF_BOTH_STOP_FIRST);
 assert(CounterfactualBarDecision(false,false,.99,1.03,1.02,1.,false)==CF_BOTH_STOP_FIRST);
 assert(CounterfactualBarDecision(false,true,1.005,1.025,1.02,1.,false)==CF_ENTRY_AMBIGUOUS);
 assert(CounterfactualBarDecision(true,false,1.005,1.025,1.,1.02,false)==CF_TARGET);
 assert(CounterfactualBarDecision(false,false,.995,1.015,1.02,1.,false)==CF_TARGET);
 assert(CounterfactualBarDecision(true,false,1.005,1.015,1.,1.02,true)==CF_HORIZON);
 assert(CounterfactualBarDecision(true,false,1.005,1.015,1.,1.02,false)==CF_WAIT);
 std::cout<<"opportunity policies: passed\n";
}
