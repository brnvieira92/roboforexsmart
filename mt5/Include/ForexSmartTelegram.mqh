#ifndef FOREX_SMART_TELEGRAM_MQH
#define FOREX_SMART_TELEGRAM_MQH
// Local terminal file only: never log token, URL, request body or response body.
string TgToken="",TgChat="";
string TgMessages[];
int TgAttempts[];
datetime TgCreated[];
ulong TgNextSend=0;
bool TgReady=false;
string TelegramEncode(string text){
 uchar bytes[];int size=StringToCharArray(text,bytes,0,WHOLE_ARRAY,CP_UTF8);string encoded="";
 for(int i=0;i<size-1;i++){uchar c=bytes[i];
 if((c>=65&&c<=90)||(c>=97&&c<=122)||(c>=48&&c<=57)||c==45||c==46||c==95||c==126)encoded+=CharToString(c);
 else encoded+=StringFormat("%%%02X",(int)c);
 }return encoded;
}
void TelegramDrop(){int n=ArraySize(TgMessages);for(int i=1;i<n;i++){TgMessages[i-1]=TgMessages[i];TgAttempts[i-1]=TgAttempts[i];TgCreated[i-1]=TgCreated[i];}
 ArrayResize(TgMessages,n-1);ArrayResize(TgAttempts,n-1);ArrayResize(TgCreated,n-1);}
void TelegramQueue(string text){
 if(!TgReady)return;
 int n=ArraySize(TgMessages);
 if(n>=100){Print("Telegram: fila cheia; nova notificação descartada.");return;}
 // No parse_mode: symbols and arbitrary text cannot inject Telegram formatting.
 ArrayResize(TgMessages,n+1);ArrayResize(TgAttempts,n+1);ArrayResize(TgCreated,n+1);
 TgMessages[n]=StringSubstr(text,0,2000);TgAttempts[n]=0;TgCreated[n]=TimeLocal();
}
bool TelegramInit(bool enabled){
 TgReady=false;TgToken="";TgChat="";ArrayResize(TgMessages,0);ArrayResize(TgAttempts,0);ArrayResize(TgCreated,0);TgNextSend=0;
 if(!enabled)return false;
 if(MQLInfoInteger(MQL_TESTER)){Print("Telegram: desativado no Testador de Estratégia.");return false;}
 int file=FileOpen("ForexSmart-telegram.txt",FILE_READ|FILE_TXT|FILE_ANSI,0,CP_UTF8);
 if(file==INVALID_HANDLE){Print("Telegram: crie MQL5/Files/ForexSmart-telegram.txt conforme README.");return false;}
 TgToken=FileReadString(file);TgChat=FileReadString(file);FileClose(file);
 StringTrimLeft(TgToken);StringTrimRight(TgToken);StringTrimLeft(TgChat);StringTrimRight(TgChat);
 int colon=StringFind(TgToken,":");bool valid=colon>0&&StringLen(TgToken)>colon+10&&StringLen(TgChat)>0;
 for(int i=0;i<StringLen(TgToken);i++){ushort c=StringGetCharacter(TgToken,i);
 if(!((c>=48&&c<=57)||(i>colon&&((c>=65&&c<=90)||(c>=97&&c<=122)||c==95||c==45))||i==colon))valid=false;}
 // Numeric chat IDs only; negative IDs support groups. No arbitrary destination URLs.
 for(int i=0;i<StringLen(TgChat);i++){ushort c=StringGetCharacter(TgChat,i);if(!((c>=48&&c<=57)||(i==0&&c==45&&StringLen(TgChat)>1)))valid=false;}
 if(!valid){TgToken="";TgChat="";Print("Telegram: arquivo local inválido; confira token e chat ID sem compartilhar valores.");return false;}
 TgReady=true;return true;
}
void TelegramPump(){
 if(!TgReady||ArraySize(TgMessages)==0||GetTickCount64()<TgNextSend)return;
 if(TimeLocal()-TgCreated[0]>300){TelegramDrop();return;}
 char data[],reply[];string headers;
 string body="chat_id="+TelegramEncode(TgChat)+"&text="+TelegramEncode(TgMessages[0]);
 int count=StringToCharArray(body,data,0,WHOLE_ARRAY,CP_UTF8);ArrayResize(data,count-1);
 ResetLastError();
 int status=WebRequest("POST","https://api.telegram.org/bot"+TgToken+"/sendMessage","Content-Type: application/x-www-form-urlencoded\r\n",1000,data,reply,headers);
 TgNextSend=GetTickCount64()+4000;
 if(status==200){Print("Telegram: notificação entregue.");TelegramDrop();return;}
 int error=GetLastError();
 // HTTP error bodies can contain sensitive request context: intentionally never print them.
 PrintFormat("Telegram: falha HTTP=%d, erro MT5=%d. Consulte README.",status,error);
 if(status==401||status==403||status==400||status==404){
 Print("Telegram: envio suspenso. Corrija configuração/permissões e recarregue o EA.");TgReady=false;TgToken="";return;}
 TgAttempts[0]++;
 if(TgAttempts[0]>=3){Print("Telegram: mensagem descartada após três tentativas.");TelegramDrop();}
 // Telegram rate limit uses a conservative cooldown. Do not replay an unbounded backlog.
 if(status==429)TgNextSend=GetTickCount64()+60000;
 else TgNextSend=GetTickCount64()+15000;
}
#endif
