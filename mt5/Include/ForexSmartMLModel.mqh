#ifndef FOREX_SMART_ML_MODEL
#define FOREX_SMART_ML_MODEL
struct MLModel {
 bool ready;string id;double mean[ML_FEATURES];double scale[ML_FEATURES];double weights[ML_FEATURES];
 double bias;double calibrationA;double calibrationB;double probabilityFloor;double winLower;double payoffLower;
 double commission;double profitFactor;double netR;int testTrades;datetime evaluationEnd;
};
MLModel model;
string MLHash(string payload){uchar bytes[],key[],digest[];int n=StringToCharArray(payload,bytes,0,WHOLE_ARRAY,CP_UTF8);ArrayResize(bytes,n-1);if(CryptEncode(CRYPT_HASH_SHA256,bytes,key,digest)<=0)return "";string result="";for(int j=0;j<ArraySize(digest);j++)result+=StringFormat("%02x",(int)digest[j]);return result;}
bool MLLoadModel(){
 ZeroMemory(model);int f=FileOpen(MODEL_FILE,FILE_READ|FILE_CSV|FILE_ANSI,';',CP_UTF8);
 if(f==INVALID_HANDLE){mlStatus="SEM MODELO: execute o preparo/treinamento no Windows";return false;}
 string keys[],values[],payload="",checksum="";int n=0;bool valid=true;
 while(!FileIsEnding(f)){
 string k=FileReadString(f),v=FileReadString(f);if(k==""&&v=="")continue;
 for(int j=0;j<n;j++)if(keys[j]==k)valid=false;
 if(k=="sha256"){if(checksum!="")valid=false;checksum=v;continue;}
 ArrayResize(keys,n+1);ArrayResize(values,n+1);keys[n]=k;values[n]=v;n++;payload+=k+";"+v+"\n";
 }FileClose(f);
 if(!valid||checksum==""||MLHash(payload)!=checksum){mlStatus="Modelo inválido: integridade/formato";return false;}
 int schema=0,policy=0,count=0,period=0,slip=0,seen=0;string qualification="",currency="";bool symbolsOK=true;
 for(int i=0;i<n;i++){
 string k=keys[i],v=values[i];double x=StringToDouble(v);
 if(k=="schema")schema=(int)x;else if(k=="policy")policy=(int)x;else if(k=="feature_count")count=(int)x;else if(k=="timeframe")period=(int)x;
 else if(k=="qualification")qualification=v;else if(k=="currency")currency=v;else if(k=="model_id")model.id=v;
 else if(k=="bias")model.bias=x;else if(k=="calibration_a")model.calibrationA=x;else if(k=="calibration_b")model.calibrationB=x;
 else if(k=="threshold")model.probabilityFloor=x;else if(k=="win_lower")model.winLower=x;else if(k=="payoff_lower")model.payoffLower=x;
 else if(k=="commission")model.commission=x;else if(k=="slippage_points")slip=(int)x;
 else if(k=="test_trades")model.testTrades=(int)x;else if(k=="test_profit_factor")model.profitFactor=x;else if(k=="test_net_R")model.netR=x;
 else if(k=="evaluation_end")model.evaluationEnd=(datetime)StringToInteger(v);
 else {bool known=false;
 for(int j=0;j<ML_FEATURES;j++){
 if(k=="mean"+(string)j){model.mean[j]=x;known=true;seen++;}
 if(k=="scale"+(string)j){model.scale[j]=x;known=true;seen++;}
 if(k=="weight"+(string)j){model.weights[j]=x;known=true;seen++;}
 }
 for(int j=0;j<4;j++)if(k=="symbol"+(string)j){symbolsOK=symbolsOK&&v==pairs[j];known=true;}
 if(!known)valid=false;
 }
 if(k!="qualification"&&k!="currency"&&k!="model_id"&&StringFind(k,"symbol")!=0&&!MathIsValidNumber(x))valid=false;
 }
 for(int j=0;j<ML_FEATURES;j++)if(!MathIsValidNumber(model.mean[j])||!MathIsValidNumber(model.weights[j])||!MathIsValidNumber(model.scale[j])||model.scale[j]<=0)valid=false;
 // These are model/data validation, not extra technical entry filters.
 if(schema!=1||policy!=ML_POLICY||count!=ML_FEATURES||period!=15||slip!=2||seen!=3*ML_FEATURES||n!=62||!symbolsOK||qualification!="QUALIFIED"||currency!="USD"||model.id==""||model.testTrades<100||model.profitFactor<1.05||model.netR<=0||model.probabilityFloor!=.55||model.calibrationA<=0||model.winLower<=0||model.winLower>=1||model.payoffLower<=0||MLKelly(model.winLower,model.payoffLower)<=0||MathAbs(model.commission-CommissionPerLotRoundTurn)>1e-8)valid=false;
 if(model.evaluationEnd<=0||TimeTradeServer()<model.evaluationEnd||TimeTradeServer()-model.evaluationEnd>90*86400){mlStatus="Modelo fora da validade temporal (ou inclui futuro do teste)";return false;}
 if(!valid){mlStatus="Modelo não qualificado ou incompatível com custos/política";return false;}
 model.ready=true;mlStatus="Modelo ML carregado: "+model.id;return true;
}
#endif
