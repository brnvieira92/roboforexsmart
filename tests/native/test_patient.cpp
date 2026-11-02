#include <cassert>
#include <cmath>
#include <iostream>
#define MathFloor std::floor
#include "../../mt5/Include/ForexSmartCore.mqh"
#include "../../mt5/Include/ForexSmartPlanMath.mqh"
int main(){
 assert(SignalPeriodMinutes(STANDARD_M5)==5);
 assert(SignalPeriodMinutes(PATIENT_M15)==15);
 assert(EffectiveWaitBars(STANDARD_M5,4,8)==4);
 assert(EffectiveWaitBars(STANDARD_M5,2,8)==2);
 assert(EffectiveWaitBars(PATIENT_M15,4,8)==8);
 const long origin=9*3600;
 const int period=SignalPeriodMinutes(PATIENT_M15)*60;
 long processed=origin;
 // Timer events/ticks throughout M15 do not generate extra signals on M5 boundaries.
 for(int minute=1;minute<15;minute++){
  long quoteTime=origin+minute*60;
  long brokerBar=quoteTime/period*period;
  assert(!NewSignalBar(brokerBar,processed));
 }
 assert(NewSignalBar(origin+period,processed));
 assert(!ConsecutiveSignalBars(origin,origin+300,period));
 assert(ConsecutiveSignalBars(origin,origin+900,period));
 assert(!ConsecutiveSignalBars(origin,origin+1800,period));
 for(int age=0;age<8;age++)assert(!OpportunityExpired(age,EffectiveWaitBars(PATIENT_M15,4,8)));
 assert(OpportunityExpired((11*3600-origin)/period,8));
 assert(!OpportunityExpired((10*3600+45*60-origin)/period,8));
 assert(OpportunityExpired(-1,8));
 int run=0;
 // Confirmed M15 breakout at 09:15 + 09:30, then separate retest 09:45, still inside horizon.
 assert(ClosedWaitEvent(WAIT_BREAKOUT,true,0,1.1,.0002,.0001,2,run,0,0,1.1,1.1003,1.1,1.1004)==0);
 assert(ClosedWaitEvent(WAIT_BREAKOUT,true,0,1.1,.0002,.0001,2,run,0,0,1.1003,1.1005,1.1002,1.1006)==1);
 assert(ClosedWaitEvent(WAIT_RETEST,true,0,1.1,.0002,.0001,2,run,0,0,1.1001,1.1004,1.10005,1.1005)==2);
 assert(!OpportunityExpired(3,8));
 // Same H1 trend policy, with closed execution bars supplied by chosen timeframe.
 assert(DetectRegime(1.12,1.11,25,1,false)==TREND_UP);
 assert(EURDirection(1.12,1.11,1.1000,1.1006,1.1002,1.1007,1.1003)==1);
 // Waiting longer never increases the cash risk budget or bypasses RR.
 assert(CashRiskBudget(24.24,5,2)==2.5);
 std::cout<<"Patient tempo policies: passed\n";
}
