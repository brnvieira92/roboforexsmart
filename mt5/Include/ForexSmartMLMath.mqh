#ifndef FOREX_SMART_ML_MATH
#define FOREX_SMART_ML_MATH
#ifdef __cplusplus
#define ML_ARRAY(name) const double name[]
#define ML_OUT(name) double name[]
#else
#define ML_ARRAY(name) const double &name[]
#define ML_OUT(name) double &name[]
#endif
#define ML_FEATURES 13
#define ML_POLICY 1
#define ML_HORIZON 8
// ML_PA_V1: M15, last 3 closed candles invalidate, TP=1.25 initial R,
// closed-bar break-even/structure trail after +1R, exit after 8 M15 bars.
double MLMin(double a,double b){return a<b?a:b;}
double MLMax(double a,double b){return a>b?a:b;}
double MLAbs(double a){return a<0?-a:a;}
double MLClip(double x){return MLMax(-10,MLMin(10,x));}
double MLDown(double x,double step){return step>0?MathFloor(x/step+1e-9)*step:0;}
double MLUp(double x,double step){return step>0?-MathFloor(-x/step+1e-9)*step:0;}
double MLVolume(double x,double step,double maximum){return step>0?MLDown(MLMin(x,maximum),step):0;}
double MLKelly(double p,double payoff){return p>=0&&p<=1&&payoff>0?p-(1-p)/payoff:0;}
double MLRiskFraction(double predicted,double empiricalLower,double payoffLower,double maximumPercent){
 return MLMax(0,MLMin(MLMin(maximumPercent,1)/100,0.25*MLKelly(MLMin(predicted,empiricalLower),payoffLower)));
}
double MLProbability(ML_ARRAY(x),ML_ARRAY(mean),ML_ARRAY(scale),ML_ARRAY(weights),double bias,double calibrationA,double calibrationB){
 double score=bias;for(int j=0;j<ML_FEATURES;j++){if(scale[j]<=0)return 0;score+=weights[j]*(x[j]-mean[j])/scale[j];}
 score=MLMax(-30,MLMin(30,calibrationA*score+calibrationB));return 1/(1+MathExp(-score));
}
bool MLFeatures(ML_ARRAY(o),ML_ARRAY(h),ML_ARRAY(l),ML_ARRAY(c),int n,bool buy,double spread,ML_OUT(x),double &volatility){
 if(n<32||spread<0)return false;
 double tr=0;for(int j=0;j<14;j++){if(h[j]<l[j]||l[j]<=0)return false;tr+=MLMax(h[j]-l[j],MLMax(MLAbs(h[j]-c[j+1]),MLAbs(l[j]-c[j+1])));}
 volatility=tr/14;if(volatility<=0)return false;
 double high=h[0],low=l[0],avg=0;for(int j=0;j<20;j++){high=MLMax(high,h[j]);low=MLMin(low,l[j]);avg+=c[j];}
 if(high<=low)return false;
 double sign=buy?1:-1,upper=h[0]-MLMax(o[0],c[0]),lower=MLMin(o[0],c[0])-l[0];
 x[0]=sign*(c[0]-o[0])/volatility;x[1]=(buy?lower:upper)/volatility;x[2]=(buy?upper:lower)/volatility;
 x[3]=sign*(c[0]-c[1])/volatility;x[4]=sign*(c[0]-c[3])/volatility;x[5]=sign*(c[0]-c[7])/volatility;
 x[6]=sign*(c[0]-avg/20)/volatility;x[7]=buy?(c[0]-low)/(high-low):(high-c[0])/(high-low);
 x[8]=(buy?high-c[0]:c[0]-low)/volatility;x[9]=(buy?c[0]-low:high-c[0])/volatility;
 x[10]=(h[0]-l[0])/volatility;x[11]=spread/volatility;x[12]=sign*(c[1]-o[1])/volatility;
 for(int j=0;j<ML_FEATURES;j++){x[j]=MLClip(x[j]);}
 return true;
}
double MLInitialStop(bool buy,ML_ARRAY(h),ML_ARRAY(l),double volatility,double spread,double tick){
 double level=buy?MLMin(l[0],MLMin(l[1],l[2])):MLMax(h[0],MLMax(h[1],h[2]));
 double buffer=MLMax(.1*volatility,spread);
 return buy?MLDown(level-buffer,tick):MLUp(level+buffer+spread,tick);
}
double MLTarget(bool buy,double entry,double sl,double tick){double distance=MLAbs(entry-sl);return buy?MLUp(entry+1.25*distance,tick):MLDown(entry-1.25*distance,tick);}
double MLTrail(bool buy,double entry,double initialR,double mark,double priorLow,double priorHigh,double buffer,double spread,double costDistance,double oldSL,double tick){
 if(initialR<=0||(buy?mark-entry:entry-mark)<initialR)return oldSL;
 double next=buy?MLMax(entry+costDistance,priorLow-buffer):MLMin(entry-costDistance,priorHigh+buffer+spread);
 next=buy?MLDown(next,tick):MLUp(next,tick);return buy?MLMax(oldSL,next):MLMin(oldSL,next);
}
#undef ML_ARRAY
#undef ML_OUT
#endif
