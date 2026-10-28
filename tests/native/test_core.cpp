#include <cassert>
#include <cmath>
#define MathFloor std::floor
#include "../../mt5/Include/ForexSmartCore.mqh"
int main(){
 SessionState session{};
 assert(ObserveAccount(session,100,1,0));assert(!session.authorized);
 session.authorized=true;assert(!ObserveAccount(session,100,1,0));assert(session.authorized);
 assert(ObserveAccount(session,100,1,2));assert(!session.authorized); // DEMO -> REAL
 session.authorized=true;assert(ObserveAccount(session,101,1,2));assert(!session.authorized);
 session.authorized=true;assert(ObserveAccount(session,101,2,2));assert(!session.authorized);
 SessionState restarted{};assert(ObserveAccount(restarted,101,2,2));assert(!restarted.authorized);
 assert(LegacyStop(.002)==.003);
 // Compare legacy math to the audited formulas over a deterministic grid.
 for(int i=1;i<=1000;i++){
 double atr=i*.000001,point=.00001,f=1.1+i*.000001,slow=1.1;
 double strength=std::fmin(1.,std::abs(f-slow)/atr);
 double expected=std::fmax(100.,std::fmin(500.,atr/point*(1+2*strength)))*point;
 assert(std::abs(LegacyTarget(atr,point,f,slow,100,500)-expected)<1e-12);
 }

 assert(LegacyDirection(2,1,1.9,2.1)==1);
 assert(LegacyDirection(1,2,1.1,0.9)==-1);
 assert(LegacyDirection(2,1,2.1,2.2)==0);
 assert(std::abs(LegacyTarget(.001,.00001,1.1,1.1,100,500)-.001)<1e-10);
 assert(std::abs(LegacyTarget(.005,.00001,1.2,1.1,100,500)-.005)<1e-10);
 assert(FloorVolume(.019,.01,100)==.01);
 assert(FloorVolume(.009,.01,100)==0);
 assert(FloorVolume(100.1,.01,2)==2);
 assert(FloorVolume(1,0,100)==0);
 assert(ReferenceEquity(9990,10000,50,0)==40);
 assert(ReferenceEquity(10990,10000,50,1000)==40);
 assert(ReferenceEquity(40,10000,50,0)<0);
 assert(RiskBudget(10000,.25)==25);
 assert(DailyBlocked(9800,10000,2));assert(!DailyBlocked(9801,10000,2));
 for(int mask=0;mask<128;mask++){
 bool a=mask&1,b=mask&2,c=mask&4,d=mask&8,e=mask&16,f=mask&32,g=mask&64;
 assert(SessionPermitted(a,b,c,d,e,f,g)==(a&&b&&!c&&!d&&e&&f&&!g));
 }
 // Exhaustive equivalence: diagnostics preserve the previous authorization gate.
 for(int bits=0;bits<2048;bits++){
 bool a=bits&1,b=bits&2,c=bits&4,d=bits&8,e=bits&16,f=bits&32,g=bits&64,h=bits&128,i=bits&256,j=bits&512,k=bits&1024;
 int mask=EntryBlocks(a,b,c,d,e,f,g,h,i,j,k);
 bool oldGate=SessionPermitted(a,b,c,d,e,e&&f&&g&&h&&i,j)&&!k;
 assert((mask==0)==oldGate);
 assert(((mask&BLOCK_AUTH)!=0)==!b);
 assert(((mask&BLOCK_TERMINAL)!=0)==!f);
 assert(((mask&BLOCK_EA)!=0)==!g);
 assert(((mask&BLOCK_ACCOUNT)!=0)==!h);
 assert(((mask&BLOCK_EXPERT)!=0)==!i);
 assert(((mask&BLOCK_CRITICAL)!=0)==k);
 }
 // An authorized session can still be blocked by a single independent permission.
 assert(EntryBlocks(true,true,false,false,true,false,true,true,true,false,false)==BLOCK_TERMINAL);
 assert(EntryBlocks(true,true,false,false,true,true,false,true,true,false,false)==BLOCK_EA);
 assert(EntryBlocks(true,true,false,false,true,true,true,false,true,false,false)==BLOCK_ACCOUNT);
 assert(EntryBlocks(true,true,false,false,true,true,true,true,false,false,false)==BLOCK_EXPERT);
 assert(TrailingCandidate(true,100,103,2)==101);
 assert(TrailingCandidate(false,100,97,2)==99);
 assert(!StopImproves(true,101,100,.01));assert(!StopImproves(false,99,100,.01));
 assert(EURDirection(2,1,.9,1.2,1,1.1,1)==1);
 assert(EURDirection(1,2,.9,1.2,1,.9,1)==-1);
 assert(EURDirection(2,1,1.1,1.2,1,1.2,1.1)==0);
 assert(JPYDirection(2,1,1.3,1.1,1.2,.8,.01)==1);
 assert(JPYDirection(1,2,.7,.9,1.2,.8,.01)==-1);
 assert(JPYDirection(2,1,1.205,1.1,1.2,.8,.01)==0);
 assert(GBPDirection(2,1,1.3,1.19,1.4,1.3,1.2,1.2,.8,.01)==1);
 assert(GBPDirection(1,2,.7,.6,.81,.7,.8,1.2,.8,.01)==-1);
 assert(GBPDirection(2,1,1.1,1.19,1.4,1.3,1.2,1.2,.8,.01)==0);
 assert(CHFDirection(.7,.9,.8,.8,1.2,1.2,25,30,70)==1);
 assert(CHFDirection(1.3,1.1,.8,.8,1.2,1.2,75,30,70)==-1);
 assert(CHFDirection(.7,.9,.8,.8,1.2,1.2,50,30,70)==0);
 assert(DetectRegime(2,1,25,1,false)==TREND_UP);
 assert(DetectRegime(1,2,25,1,false)==TREND_DOWN);
 assert(DetectRegime(1,2,15,1,false)==CONSOLIDATION);
 assert(DetectRegime(1,2,25,3,false)==HIGH_VOLATILITY);
 assert(DetectRegime(1,2,25,.3,false)==LOW_VOLATILITY);
 assert(DetectRegime(1,2,25,1,true)==BREAKOUT);
 assert(DetectRegime(1,2,19,1,false)==TRANSITION);
 assert(DetectRegime(1,2,19,0,false)==NO_TRADE);
}
