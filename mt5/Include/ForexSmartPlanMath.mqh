#ifndef FOREX_SMART_PLAN_MATH
#define FOREX_SMART_PLAN_MATH
// Pure policies compiled directly by both MQL5 and the native regression harness.
#ifdef __cplusplus
#define FS_PLAN_ARRAY(name) const double name[]
#else
#define FS_PLAN_ARRAY(name) const double &name[]
#endif
enum EntryPlannerSelection { PREVIOUS_PLAN=0, TECHNICAL_PLAN=1 };
enum PlannedExitSelection { FULL_TECHNICAL_TARGET=0, PARTIAL_AND_TRAIL=1 };
enum PlannedTrailSelection { CONFIRMED_STRUCTURE=0, VOLATILITY_WITH_STRUCTURE=1 };
double PipSize(double pointSize,int quoteDigits){return pointSize*((quoteDigits==3||quoteDigits==5)?10:1);}
double TickDown(double priceValue,double tickSize){return tickSize>0?MathFloor(priceValue/tickSize+1e-9)*tickSize:0;}
double TickUp(double priceValue,double tickSize){return tickSize>0?-MathFloor(-priceValue/tickSize+1e-9)*tickSize:0;}
double TrueRange(double candleHigh,double candleLow,double priorClose){return FSMax(candleHigh-candleLow,FSMax(FSAbs(candleHigh-priorClose),FSAbs(candleLow-priorClose)));}
// Index 0 is the newest CLOSED candle. One additional old close is needed for TR.
double WilderATR(FS_PLAN_ARRAY(h),FS_PLAN_ARRAY(l),FS_PLAN_ARRAY(c),int count,int period){
 if(period<=0||count<period+1)return 0;
 double result=0;int samples=0;
 for(int i=count-2;i>=0;i--){double tr=TrueRange(h[i],l[i],c[i+1]);
 if(tr<0||h[i]<l[i])return 0;
 samples++;if(samples<=period){result+=tr;if(samples==period)result/=period;}
 else result=(result*(period-1)+tr)/period;
 }return samples>=period?result:0;
}
// A candidate needs left older candles AND right newer closed candles. Never uses bar 0 in formation.
bool ConfirmedPivot(FS_PLAN_ARRAY(v),int count,int index,int left,int right,bool highPivot){
 if(left<1||right<1||index<right||index+left>=count)return false;
 for(int k=1;k<=left;k++)if(highPivot?v[index]<=v[index+k]:v[index]>=v[index+k])return false;
 for(int k=1;k<=right;k++)if(highPivot?v[index]<=v[index-k]:v[index]>=v[index-k])return false;
 return true;
}
int FindInvalidation(FS_PLAN_ARRAY(h),FS_PLAN_ARRAY(l),int count,int left,int right,int maxAge,bool buy,double entryPrice){
 for(int i=right;i<count-left&&i<=maxAge;i++){
 if(buy&&l[i]<entryPrice&&ConfirmedPivot(l,count,i,left,right,false))return i;
 if(!buy&&h[i]>entryPrice&&ConfirmedPivot(h,count,i,left,right,true))return i;
 }return -1;
}
int FindObstacle(FS_PLAN_ARRAY(h),FS_PLAN_ARRAY(l),int count,int left,int right,int maxAge,bool buy,double entryPrice){
 int best=-1;
 for(int i=right;i<count-left&&i<=maxAge;i++){
 if(buy&&h[i]>entryPrice&&ConfirmedPivot(h,count,i,left,right,true)&&(best<0||h[i]<h[best]))best=i;
 if(!buy&&l[i]<entryPrice&&ConfirmedPivot(l,count,i,left,right,false)&&(best<0||l[i]>l[best]))best=i;
 }return best;
}
enum ObstacleSelectionPolicy { ALL_CONFIRMED_PIVOTS=0, RETESTED_OR_M15=1, M15_CONFIRMED_ONLY=2 };
// Count separated touches AFTER a pivot, excluding the candles that confirmed it.
int PivotTouches(FS_PLAN_ARRAY(h),FS_PLAN_ARRAY(l),int count,int pivot,int right,bool highLevel,double level,double tolerance,int separation,int &span){
 if(pivot<0||pivot>=count||right<1||separation<1){span=0;return 0;}
 int touches=1,last=pivot,newest=pivot;
 for(int j=pivot-right-1;j>=0;j--){double price=highLevel?h[j]:l[j];
 if(last-j>=separation&&FSAbs(price-level)<=tolerance){touches++;last=j;newest=j;}}
 span=pivot-newest;return touches;
}
bool PivotBroken(FS_PLAN_ARRAY(c),int count,int pivot,int right,bool highLevel,double level,double tolerance,int confirmations){
 if(confirmations<1||pivot<right||pivot>=count)return false;
 int run=0;
 for(int j=pivot-right-1;j>=0;j--){bool beyond=highLevel?c[j]>level+tolerance:c[j]<level-tolerance;
 run=beyond?run+1:0;if(run>=confirmations)return true;}return false;
}
int ConfluencePivotIndex(FS_PLAN_ARRAY(h),FS_PLAN_ARRAY(l),int count,int left,int right,bool highLevel,double level,double tolerance){
 for(int i=right;i<count-left;i++){
 if(highLevel&&ConfirmedPivot(h,count,i,left,right,true)&&FSAbs(h[i]-level)<=tolerance)return i;
 if(!highLevel&&ConfirmedPivot(l,count,i,left,right,false)&&FSAbs(l[i]-level)<=tolerance)return i;
 }return -1;
}
bool ObstacleQualified(int policy,int touches,int span,int minimumTouches,int minimumSpan,bool m15,bool broken){
 if(policy==ALL_CONFIRMED_PIVOTS)return true;
 if(broken)return false;
 if(policy==M15_CONFIRMED_ONLY)return m15;
 return m15||(touches>=minimumTouches&&span>=minimumSpan);
}
// State-machine decision: 0=cancel, 1=wait, 2=recheck. Time units are seconds.
int RetryDecision(bool sameAccount,bool sameSession,bool permitted,bool sameBar,bool sameSignal,bool dispatched,int attempts,int maximum,long age,long delayElapsed,int interval,int lifetime){
 if(!sameAccount||!sameSession||!permitted||!sameBar||!sameSignal||dispatched||attempts>=maximum||age<0||age>=lifetime)return 0;
 return delayElapsed>=interval?2:1;
}
double TechnicalStop(bool buy,double entryPrice,double bid,double ask,double structureBid,double buffer,double atrDistance,double minimumDistance,double tickSize){
 double raw=buy?FSMin(structureBid-buffer,FSMin(entryPrice-atrDistance,bid-minimumDistance)):
 FSMax(structureBid+buffer+(ask-bid),FSMax(entryPrice+atrDistance,ask+minimumDistance));
 return buy?TickDown(raw,tickSize):TickUp(raw,tickSize);
}
// Return 0=skip, 1=write, 2=prune oldest then write. Never changes trade permission.
int SnapshotCapacityAction(int existing,int maximum,bool allowPrune){if(maximum<1||existing<0)return 0;if(existing<maximum)return 1;return allowPrune?2:0;}
double SignedTargetDistance(bool buy,double entryPrice,double targetPrice){return buy?targetPrice-entryPrice:entryPrice-targetPrice;}
double ExtensionVolumeLimit(double originalLot,double recalculatedLot){return FSMin(originalLot,recalculatedLot);}
bool TargetExtends(bool buy,double oldTarget,double candidate,double tickSize){return buy?candidate>oldTarget+tickSize*0.5:candidate<oldTarget-tickSize*0.5;}
double TechnicalTarget(bool buy,double entryPrice,double spread,double obstacleBid,double clearance,double initialR,double maxTargetR,double tickSize){
 double raw=buy?FSMin(obstacleBid-clearance,entryPrice+initialR*maxTargetR):FSMax(obstacleBid+spread+clearance,entryPrice-initialR*maxTargetR);
 return buy?TickDown(raw,tickSize):TickUp(raw,tickSize);
}
bool StopWithinLimit(double distance,double maximumPips,double pip,double tickSize){return distance>0&&pip>0&&distance<=maximumPips*pip+tickSize*1e-6;}
bool ManagementProgress(double gain,double initialR,double thresholdR){return initialR>0&&thresholdR>=1&&gain>=initialR*thresholdR;}
double CostedVolume(double budget,double lossPerLot,double costsPerLot,double step,double maximum){
 return lossPerLot>0&&costsPerLot>=0?FloorVolume(budget/(lossPerLot+costsPerLot),step,maximum):0;
}
double ProjectedGrossWin(double fullWinPerLot,double partialWinPerLot,double totalLot,double partialLot){return fullWinPerLot*(totalLot-partialLot)+partialWinPerLot*partialLot;}
double NetRewardRisk(double grossWin,double grossLoss,double costs){return grossLoss+costs>0?(grossWin-costs)/(grossLoss+costs):0;}
bool TargetFits(bool buy,double entryPrice,double sl,double tp,double obstacleBid,double spread,double clearance,double tickSize){
 if(buy)return sl<entryPrice&&tp>entryPrice&&tp<=obstacleBid-clearance+tickSize*1e-6;
 return sl>entryPrice&&tp<entryPrice&&tp>=obstacleBid+spread+clearance-tickSize*1e-6;
}
#undef FS_PLAN_ARRAY
#endif
