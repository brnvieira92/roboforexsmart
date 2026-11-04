#include <cassert>
#include <cmath>
#include <iomanip>
#include <iostream>
#define MathFloor std::floor
#define MathExp std::exp
#include "../../mt5/Include/ForexSmartMLMath.mqh"
int main(){
 assert(std::abs(MLKelly(.7,3)-.6)<1e-12);
 assert(MLRiskFraction(.4,.4,.5,.25)==0);
 assert(MLRiskFraction(.9,.8,2,5)<=.01);
 assert(MLVolume(.0199,.01,100)==.01);assert(MLVolume(.009,.01,100)==0);
 double o[32],h[32],l[32],c[32],x[ML_FEATURES],a=0;
 for(int i=0;i<32;i++){o[i]=1.1+i*.0001;h[i]=o[i]+.0002;l[i]=o[i]-.00015;c[i]=o[i]+.00005;}
 assert(MLFeatures(o,h,l,c,32,true,.0001,x,a));
 assert(!MLFeatures(o,h,l,c,10,true,.0001,x,a));
 assert(MLFeatures(o,h,l,c,32,true,.0001,x,a));
 double mean[ML_FEATURES],scale[ML_FEATURES],w[ML_FEATURES];for(int j=0;j<ML_FEATURES;j++){mean[j]=0;scale[j]=1;w[j]=j*.01;}
 double p=MLProbability(x,mean,scale,w,-.3,.9,.2);assert(p>0&&p<1);
 double sl=MLInitialStop(true,h,l,a,.0001,.00001);assert(sl<l[0]);
 double next=MLTrail(true,1.1,.001,1.1012,1.1003,1.1015,.0001,.0001,.00004,1.099,.00001);
 assert(next>=1.10004);assert(MLTrail(true,1.1,.001,1.1005,1.1003,1.1015,.0001,.0001,.00004,1.099,.00001)==1.099);
 assert(MLTrail(true,1.1,.001,1.1012,1.1003,1.1015,.0001,.0001,.00004,1.101,.00001)>=1.101);
 std::cout<<std::setprecision(17)<<a<<' '<<p;for(double v:x)std::cout<<' '<<v;std::cout<<'\n';
}
