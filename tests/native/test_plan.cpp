#include <cassert>
#include <cmath>
#include <iostream>
#define MathFloor std::floor
#include "../../mt5/Include/ForexSmartCore.mqh"
#include "../../mt5/Include/ForexSmartPlanMath.mqh"
static bool near(double a,double b){return std::abs(a-b)<1e-9;}
int main(){
 assert(near(PipSize(.00001,5),.0001));assert(near(PipSize(.001,3),.01));
 assert(near(PipSize(.0001,4),.0001));assert(near(PipSize(.01,2),.01));
 assert(near(TickDown(1.123456,.00001),1.12345));assert(near(TickUp(1.123456,.00001),1.12346));
 assert(TrueRange(12,10,9)==3);assert(TrueRange(12,10,13)==3);
 double highs[40],lows[40],closes[40];
 for(int j=0;j<40;j++){highs[j]=11;lows[j]=9;closes[j]=10;}
 assert(near(WilderATR(highs,lows,closes,40,14),2));assert(WilderATR(highs,lows,closes,14,14)==0);
 highs[0]=13;assert(near(WilderATR(highs,lows,closes,40,14),2+2./14));
 // Series arrays contain CLOSED bars only; the newest extreme cannot be a confirmed pivot.
 double h[]={5,6,9,6,5,7,10,7,5,6,8,6};
 double l[]={3,2,1,2,3,2,0.5,2,3,2,1,2};
 assert(!ConfirmedPivot(h,12,0,2,2,true));assert(!ConfirmedPivot(h,12,1,2,2,true));
 assert(ConfirmedPivot(h,12,2,2,2,true));assert(ConfirmedPivot(l,12,2,2,2,false));
 assert(FindInvalidation(h,l,12,2,2,5,true,4)==2);
 assert(FindInvalidation(h,l,12,2,2,1,true,4)==-1);
 assert(FindObstacle(h,l,12,2,2,9,true,6)==2); // nearest confirmed resistance: 9, not 10
 assert(FindObstacle(h,l,12,2,2,9,true,11)==-1);
 // Invalidation is beyond closed structure; stop rounding never moves it inward.
 double buySL=TechnicalStop(true,1.10012,1.10000,1.10012,1.09900,.0002,.00045,.00002,.00001);
 double sellSL=TechnicalStop(false,1.10000,1.10000,1.10012,1.10100,.0002,.00045,.00002,.00001);
 assert(near(buySL,1.09880));assert(near(sellSL,1.10132));
 assert(near(sellSL-(1.10100+.0002),.00012)); // exactly one Bid->Ask conversion
 assert(StopWithinLimit(1.10012-buySL,20,.0001,.00001));
 assert(!StopWithinLimit(1.10012-buySL,12,.0001,.00001)); // reject, do not clamp SL
 double jpySL=TechnicalStop(true,157.987,157.975,157.987,157.9,.02,.15,.003,.001);
 assert(jpySL<=157.837+1e-9);
 double target=TechnicalTarget(true,1.10012,.00012,1.104,.0002,1.10012-buySL,3,.00001);
 assert(target<=1.1038+1e-9);assert(TargetFits(true,1.10012,buySL,target,1.104,.00012,.0002,.00001));
 double sellTP=TechnicalTarget(false,1.100,.00012,1.096,.0002,sellSL-1.100,3,.00001);
 assert(sellTP>=1.09632-1e-9);assert(TargetFits(false,1.100,sellSL,sellTP,1.096,.00012,.0002,.00001));
 assert(!TargetFits(true,1.1,1.09,1.105,1.104,.00012,.0002,.00001));
 // Mandatory EURUSD example: broker profit calc mocked using 100,000 EUR contract / USD account.
 double budget=23.46,lossPerLot=100000*.0015;
 assert(near(budget/lossPerLot,.1564));double lot=CostedVolume(budget,lossPerLot,0,.01,100);
 assert(near(lot,.15));assert(near(lot*lossPerLot,22.5));
 assert(CostedVolume(.1,lossPerLot,0,.01,100)==0); // impossible minimum lot is rejected by adapter
 assert(CostedVolume(budget,lossPerLot,7,.01,100)<=lot);
 assert(near(NetRewardRisk(300,150,0),2));assert(NetRewardRisk(300,150,7)<2);
 assert(near(ProjectedGrossWin(300,150,.2,.1),45));
 assert(near(ProjectedGrossWin(300,150,.01,0),3));
 assert(NetRewardRisk(5,24,0)<1); // no monetary target override
 assert(!ManagementProgress(.00055,.00078,1.5));assert(ManagementProgress(.00117,.00078,1.5));
 assert(!StopImproves(true,1.099,1.098,.00001));assert(!StopImproves(false,1.101,1.102,.00001));
 // A farther target is possible only when the SAME obstacle already provides space.
 double entry=1.1,sl=1.099,obstacle=1.106,clearance=.0002,tick=.00001;
 double base=TechnicalTarget(true,entry,.0001,obstacle,clearance,entry-sl,3,tick);
 double extended=TechnicalTarget(true,entry,.0001,obstacle,clearance,entry-sl,4,tick);
 assert(TargetExtends(true,base,extended,tick));assert(TargetFits(true,entry,sl,extended,obstacle,.0001,clearance,tick));
 assert(near(ExtensionVolumeLimit(.15,.16),.15));assert(near(ExtensionVolumeLimit(.15,.14),.14));
 double nearObstacle=1.102;
 assert(near(TechnicalTarget(true,entry,.0001,nearObstacle,clearance,entry-sl,3,tick),TechnicalTarget(true,entry,.0001,nearObstacle,clearance,entry-sl,4,tick)));
 // Uploaded SELL snapshot: increasing R cap cannot cross nearby support 1.11990.
 double blocked3=TechnicalTarget(false,1.11994,.00010,1.11990,.00020,.00090,3,.00001);
 double blocked4=TechnicalTarget(false,1.11994,.00010,1.11990,.00020,.00090,4,.00001);
 assert(near(blocked3,1.12020));assert(near(blocked3,blocked4));
 assert(SignedTargetDistance(false,1.11994,blocked4)<0);
 assert(!TargetFits(false,1.11994,1.12084,blocked4,1.11990,.00010,.00020,.00001));
 assert(SnapshotCapacityAction(29,30,false)==1);
 assert(SnapshotCapacityAction(30,30,false)==0);
 assert(SnapshotCapacityAction(30,30,true)==2);
 assert(SnapshotCapacityAction(50,30,false)==0);
 assert(SnapshotCapacityAction(0,0,true)==0);
 {
 double rh[]={1.2,1.2,1.2,1.2,1.2,1.2,1.2,1.2,1.2};
 double rl[]={1.1,1.002,1.004,1.005,1.1,1.1,1.0,1.1,1.1};
 double rc[]={1.1,1.1,1.1,1.1,1.1,1.1,1.1,1.1,1.1};int span=0;
 assert(PivotTouches(rh,rl,9,6,2,false,1.0,.01,2,span)==3&&span==5);
 assert(!PivotBroken(rc,9,6,2,false,1.0,.01,2)); // wicks/touches are not confirmed breaks
 rc[3]=.98;rc[2]=.98;assert(PivotBroken(rc,9,6,2,false,1.0,.01,2));
 assert(!PivotBroken(rc,9,6,2,true,1.2,.01,2));
 rc[3]=1.22;rc[2]=1.22;assert(PivotBroken(rc,9,6,2,true,1.2,.01,2));
 double mh[]={1.6,1.7,2.0,1.7,1.6},ml[]={1.2,1.2,1.2,1.2,1.2};
 assert(ConfluencePivotIndex(mh,ml,5,2,2,true,2.003,.01)==2);
 assert(ConfluencePivotIndex(mh,ml,5,2,2,true,2.03,.01)==-1);
 double supportM15[]={1.4,1.3,1.1,1.3,1.4};
 assert(ConfluencePivotIndex(mh,supportM15,5,2,2,false,1.103,.01)==2);
 assert(ObstacleQualified(ALL_CONFIRMED_PIVOTS,1,0,2,3,false,true)); // compatibility baseline
 assert(!ObstacleQualified(RETESTED_OR_M15,1,0,2,3,false,false));
 assert(ObstacleQualified(RETESTED_OR_M15,3,5,2,3,false,false));
 assert(!ObstacleQualified(M15_CONFIRMED_ONLY,3,5,2,3,false,false));
 assert(ObstacleQualified(M15_CONFIRMED_ONLY,1,0,2,3,true,false));
 assert(!ObstacleQualified(RETESTED_OR_M15,3,5,2,3,true,true));
 }
 assert(RetryDecision(true,true,true,true,true,false,0,3,5,5,10,60)==1);
 assert(RetryDecision(true,true,true,true,true,false,0,3,10,10,10,60)==2);
 assert(RetryDecision(true,true,true,true,true,false,3,3,30,10,10,60)==0);
 assert(RetryDecision(true,true,true,true,true,false,0,3,60,10,10,60)==0);
 // Every independent loss of validity must cancel, even before a retry becomes due.
 for(int flag=0;flag<6;flag++){
 bool flags[]={true,true,true,true,true,false};flags[flag]=!flags[flag];
 assert(RetryDecision(flags[0],flags[1],flags[2],flags[3],flags[4],flags[5],0,3,10,10,10,60)==0);
 }
 // Additional stop width changes volume, not the authorized monetary budget.
 for(int pips=5;pips<=40;pips++){
 double loss=100000*pips*.0001;double volume=CostedVolume(25,loss,7,.01,100);
 assert(volume*(loss+7)<=25+1e-9);
 }
 std::cout << "Technical planner policies: PASS\n";
}
