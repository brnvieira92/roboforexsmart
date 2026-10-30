#ifndef FOREX_SMART_ACCOUNT
#define FOREX_SMART_ACCOUNT
string accountScope="",accountIdentity="";
SessionState sessionState;
bool emergencyStop=false,criticalFailure=false;
bool journalWritable=false,journalFailureLatched=false;
int journalLastError=0;string journalFailureStage="";ulong journalLastNotice=0;
string lastReject="",lastStrategy="LEGACY",lastRegime="NO_TRADE";
double lastAggregateRisk=0;
string AccountKind(){long m=AccountInfoInteger(ACCOUNT_TRADE_MODE);if(m==ACCOUNT_TRADE_MODE_DEMO)return "DEMO";if(m==ACCOUNT_TRADE_MODE_REAL)return "REAL";return "CONTEST";}
string Identity(){return (string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+AccountInfoString(ACCOUNT_SERVER)+"|"+(string)AccountInfoInteger(ACCOUNT_TRADE_MODE);}
ulong TextFingerprint(string server){ulong hash=1469598103934665603;for(int i=0;i<StringLen(server);i++){hash^=(ulong)StringGetCharacter(server,i);hash*=1099511628211;}return hash;}
ulong ServerFingerprint(){return TextFingerprint(AccountInfoString(ACCOUNT_SERVER));}
string ServerHash(){return StringFormat("%I64X",ServerFingerprint());}
string BarKey(string symbol){return StateKey("b."+StringFormat("%I64X",TextFingerprint(symbol)));}
string StateKey(string suffix){return "FS2."+accountScope+"."+suffix;}
string ModeName(){return StrategyMode==LEGACY?"LEGACY":"MULTISTRATEGY";}
void ResetTelegramAccount(){ArrayResize(TgMessages,0);ArrayResize(TgAttempts,0);ArrayResize(TgCreated,0);}
// Returns true only after identity has been refreshed. Always starts disarmed.
void SyncAccount(){ObserveAccount(sessionState,AccountInfoInteger(ACCOUNT_LOGIN),(long)ServerFingerprint(),(int)AccountInfoInteger(ACCOUNT_TRADE_MODE));string current=Identity();if(current==accountIdentity)return;
 activePlanID="";accountIdentity=current;accountScope=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"."+ServerHash();
 sessionState.authorized=false;entriesPaused=false;emergencyStop=false;criticalFailure=false;dayKey=-1;dayEquity=0;lossNotified=false;
 journalWritable=false;journalFailureLatched=false;journalLastError=0;journalFailureStage="";journalLastNotice=0;
 ResetTelegramAccount();lastReject="Nova sessão: ativação manual obrigatória";
 Print("Forex Smart: conta ",AccountKind()," identificada. Novas entradas desarmadas.");
}
void Reject(string reason){if(activePlanID!="")reason="plan="+activePlanID+" | "+reason;lastReject=reason;Journal("reject",ModeName()+" | "+lastStrategy+" | "+reason);Print("Entrada bloqueada: ",reason);TelegramQueue("Forex Smart | "+AccountKind()+" | "+ModeName()+" | "+lastStrategy+" | Entrada rejeitada: "+reason);}
bool Permissions(){return TerminalInfoInteger(TERMINAL_CONNECTED)&&TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)&&MQLInfoInteger(MQL_TRADE_ALLOWED)&&AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)&&AccountInfoInteger(ACCOUNT_TRADE_EXPERT);}
int RuntimeEntryBlocks(){return EntryBlocks(AutoTrade,sessionState.authorized,entriesPaused,emergencyStop,
 TerminalInfoInteger(TERMINAL_CONNECTED),TerminalInfoInteger(TERMINAL_TRADE_ALLOWED),
 MQLInfoInteger(MQL_TRADE_ALLOWED),AccountInfoInteger(ACCOUNT_TRADE_ALLOWED),
 AccountInfoInteger(ACCOUNT_TRADE_EXPERT),AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_CONTEST,criticalFailure);}
string EntryBlockDetails(int mask){
 string reason="";
 if((mask&BLOCK_AUTO)!=0)reason+="AutoTrade=false; ";
 if((mask&BLOCK_AUTH)!=0)reason+="sessão desarmada (ativação manual necessária); ";
 if((mask&BLOCK_PAUSED)!=0)reason+="Pausar entradas ativo; ";
 if((mask&BLOCK_EMERGENCY)!=0)reason+="emergência ativa; ";
 if((mask&BLOCK_CONNECTION)!=0)reason+="terminal desconectado; ";
 if((mask&BLOCK_TERMINAL)!=0)reason+="Algo Trading desabilitado no terminal (TERMINAL_TRADE_ALLOWED=false); ";
 if((mask&BLOCK_EA)!=0)reason+="negociação desabilitada nas permissões do EA (MQL_TRADE_ALLOWED=false); ";
 if((mask&BLOCK_ACCOUNT)!=0)reason+="conta sem permissão de negociação (ACCOUNT_TRADE_ALLOWED=false); ";
 if((mask&BLOCK_EXPERT)!=0)reason+="conta sem permissão para robôs (ACCOUNT_TRADE_EXPERT=false); ";
 if((mask&BLOCK_CONTEST)!=0)reason+="conta CONTEST não autorizada; ";
 if((mask&BLOCK_CRITICAL)!=0){
 if(journalFailureLatched)reason+="falha de histórico CSV (último erro="+(string)journalLastError+", etapa="+journalFailureStage+"); escrita agora="+(journalWritable?"disponível; reativação manual necessária":"indisponível; feche Excel/editores e confira acesso/disco")+"; ";
 else reason+="falha crítica interna: consulte Experts e CSV antes de reativar; ";
 }
 return mask==0?"nenhum bloqueio de sessão; custos e risco ainda precisam passar nas validações":reason;
}
bool EntrySession(){return RuntimeEntryBlocks()==0;}
string SessionDiagnostic(){int mask=RuntimeEntryBlocks();return "Conta="+AccountKind()+" | Modo="+ModeName()+" | Sessão="+(sessionState.authorized?"AUTORIZADA":"DESARMADA")+" | máscara="+(string)mask+" | "+EntryBlockDetails(mask);}
void ReportSession(){
 // Journal can revoke authorization: always build the displayed status AFTER the write.
 Journal("session_status",SessionDiagnostic());Notify(SessionDiagnostic());
}

double RelevantEquity(){
 double actual=AccountInfoDouble(ACCOUNT_EQUITY);
 if(!UseReferenceCapital||AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO)return actual;
 // A persistent virtual equity tracks the whole account from first enabling the feature.
 // Deposits/withdrawals are neutralized using balance-only cash-flow deals.
 string startKey=StateKey("ref.time"),baseKey=StateKey("ref.eq"),amountKey=StateKey("ref.amount"),flowKey=StateKey("ref.cash");
 double flows=0;
 if(!HistorySelect(0,TimeCurrent()))return 0;
 for(int i=0;i<HistoryDealsTotal();i++){ulong d=HistoryDealGetTicket(i);long t=HistoryDealGetInteger(d,DEAL_TYPE);if(t==DEAL_TYPE_BALANCE||t==DEAL_TYPE_CREDIT)flows+=HistoryDealGetDouble(d,DEAL_PROFIT);}
 if(!GlobalVariableCheck(startKey)){GlobalVariableSet(startKey,(double)TimeCurrent());GlobalVariableSet(baseKey,actual);GlobalVariableSet(amountKey,ReferenceCapital);GlobalVariableSet(flowKey,flows);GlobalVariablesFlush();}
 if(!GlobalVariableCheck(baseKey)||!GlobalVariableCheck(amountKey)||!GlobalVariableCheck(flowKey)||GlobalVariableGet(amountKey)!=ReferenceCapital)return 0;
 return ReferenceEquity(actual,GlobalVariableGet(baseKey),ReferenceCapital,flows-GlobalVariableGet(flowKey));
}
#endif
