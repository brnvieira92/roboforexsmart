#property strict
#property script_show_inputs
#include "../Experts/Include/ForexSmartCore.mqh"
#include "../Experts/Include/ForexSmartPlanMath.mqh"
int failures=0;
void Check(bool result,string label){if(!result){Print("FAIL: ",label);failures++;}}
void OnStart(){
 // Pure simulations: never send orders, access credentials or call Telegram.
 Check(MathAbs(PipSize(.00001,5)-.0001)<1e-12,"EUR pip");Check(MathAbs(PipSize(.001,3)-.01)<1e-12,"JPY pip");
 double h[20],l[20],c[20];for(int i=0;i<20;i++){h[i]=11;l[i]=9;c[i]=10;}
 Check(MathAbs(WilderATR(h,l,c,20,14)-2)<1e-12,"Wilder ATR");
 Check(!ConfirmedPivot(h,20,0,2,2,true),"Unconfirmed pivot excluded");
 double lot=CostedVolume(23.46,150,0,.01,100);Check(MathAbs(lot-.15)<1e-12,"Mandatory lot .15");Check(MathAbs(lot*150-22.5)<1e-12,"Mandatory risk 22.50");
 double stop=TechnicalStop(false,1.10000,1.10000,1.10012,1.101,.0002,.00045,.00002,.00001);
 Check(MathAbs(stop-1.10132)<1e-9,"Sell Bid to Ask once");
 Check(!StopWithinLimit(.00132,12,.0001,.00001),"Reject wide stop, never clamp");
 Check(NetRewardRisk(300,150,7)<2,"Costs reduce RR");
 Check(RetryDecision(true,true,true,true,true,false,0,3,10,10,10,60)==2,"Recheck due");
 Check(RetryDecision(true,true,true,true,true,true,0,3,10,10,10,60)==0,"No retry after dispatch");
 Check(RetryDecision(true,true,true,true,true,false,0,3,60,10,10,60)==0,"TTL expiry");
 Check(!ObstacleQualified(M15_CONFIRMED_ONLY,3,5,2,3,false,false),"Local retest is not M15 proof");
 Check(ObstacleQualified(M15_CONFIRMED_ONLY,1,0,2,3,true,false),"M15 confluence");
 Check(!ObstacleQualified(RETESTED_OR_M15,3,5,2,3,true,true),"Confirmed broken pivot excluded in experimental policy");
 Print(failures==0?"Forex Smart plan simulations: PASS":"Forex Smart plan simulations: FAIL");
}
