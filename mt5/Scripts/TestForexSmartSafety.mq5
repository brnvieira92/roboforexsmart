#property strict
#property script_show_inputs
#include "../Experts/Include/ForexSmartCore.mqh"
int failures=0;
void Check(bool condition,string label){if(!condition){failures++;Print("FAIL: ",label);}}
void OnStart(){
 // Pure simulations: no trade library, broker calls, WebRequest or order submission.
 SessionState s; s.identified=false;s.authorized=false;
 Check(ObserveAccount(s,10,11,0)&&!s.authorized,"initial demo disarmed");
 s.authorized=true;Check(!ObserveAccount(s,10,11,0)&&s.authorized,"same session");
 Check(ObserveAccount(s,10,11,2)&&!s.authorized,"real type revokes authorization");
 s.authorized=true;Check(ObserveAccount(s,12,11,2)&&!s.authorized,"login revokes");
 s.authorized=true;Check(ObserveAccount(s,12,13,2)&&!s.authorized,"server revokes");
 Check(!SessionPermitted(true,false,false,false,true,true,false),"no inherited authorization");
 Check(SessionPermitted(true,true,false,false,true,true,false),"demo or real authorized");
 Check(!SessionPermitted(true,true,false,false,true,true,true),"contest blocked");
 Check(!SessionPermitted(true,true,false,true,true,true,false),"emergency blocks");
 Check(!SessionPermitted(true,true,false,false,false,true,false),"disconnected blocks");
 Check(RiskBudget(10000,.25)==25,"risk budget");
 Check(FloorVolume(.019,.01,10)==.01,"lot rounds down");
 Check(DailyBlocked(9800,10000,2),"daily limit");
 Check(LegacyDirection(2,1,1.9,2.1)==1,"legacy long");
 Check(LegacyDirection(1,2,1.1,.9)==-1,"legacy short");
 Check(!StopImproves(true,101,100,.01),"long SL cannot loosen");
 Check(!StopImproves(false,99,100,.01),"short SL cannot loosen");
 Print(failures==0?"Forex Smart safety simulations: PASS":"Forex Smart safety simulations: FAIL");
}
