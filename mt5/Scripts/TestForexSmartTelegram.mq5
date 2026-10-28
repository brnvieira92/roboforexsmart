#property strict
#property script_show_inputs
#include "../Experts/Include/ForexSmartTelegram.mqh"
int failures=0;
void Check(bool condition,string name){if(!condition){Print("FAIL: ",name);failures++;}}
void OnStart(){
 Check(TelegramEncode("EURUSD# &+=\n") == "EURUSD%23%20%26%2B%3D%0A","reserved bytes");
 Check(TelegramEncode("ação") == "a%C3%A7%C3%A3o","UTF-8");
 Check(TelegramEncode("AZaz09-._~")=="AZaz09-._~","unreserved");
 TgReady=false;TelegramQueue("ignored");Check(ArraySize(TgMessages)==0,"disabled queue");
 TgReady=true;TelegramQueue("first");TelegramQueue("second");TgAttempts[1]=2;
 TelegramDrop();Check(ArraySize(TgMessages)==1&&TgMessages[0]=="second"&&TgAttempts[0]==2,"FIFO metadata");
 TelegramDrop();for(int i=0;i<101;i++)TelegramQueue((string)i);
 Check(ArraySize(TgMessages)==100&&TgMessages[0]=="0"&&TgMessages[99]=="99","bounded queue");
 TgCreated[0]=TimeLocal()-301;TelegramPump();Check(ArraySize(TgMessages)==99&&TgMessages[0]=="1","expiration without HTTP");
 TgReady=false;TgToken="";TgChat="";
 if(failures==0)Print("Telegram unit tests: PASS");else Print("Telegram unit tests: FAIL count=",failures);
}
