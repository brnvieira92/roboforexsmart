# v2.16 — modo paciente M15

Modo separado e opcional. O padrão continua `EntryTempo=STANDARD_M5`. Para usar o modo paciente com a meta líquida estimada5USD que você escolheu:

```text
AutoTrade                 = true
StrategyMode              = MULTISTRATEGY
EntryPlanner              = TECHNICAL_PLAN
EntryTempo                = PATIENT_M15
PatientWaitBars           = 8
PlanUseEventWaits         = true
PlanEnableTrendPullback   = true
PlanEnableBreakRetest     = false
PlanTargetMode            = FIXED_NET_USD
PlanNetProfitUSD          = 5.0
```

Mantenha habilitadas as estratégias dos pares desejados. Sessão precisa estar manualmente autorizada. PATIENT_M15 exige MULTISTRATEGY, TECHNICAL_PLAN, esperas por eventos e ao menos um módulo de espera habilitado; combinação inválida gera mensagem e falha de inicialização. Não rearma permissões.

## O que muda de verdade

| Componente | STANDARD_M5 | PATIENT_M15 |
|---|---|---|
| Sinal e velas de confirmação | M5 fechado | M15 fechado |
| EMA20, bandas e RSI de execução | M5 | M15 |
| ATR dos sinais / comparação de volatilidade | M5 | M15 |
| Tendência EMA50/200 | H1 fechado | H1 fechado |
| ADX | M15 | M15 |
| Estrutura de SL/TP / ATR Wilder do plano | Plan*Timeframe do par | M15, independentemente desses inputs |
| Prazo das esperas estruturais | Plan*WaitBars | PatientWaitBars8 |
| Identidade de sinais / persistência | *_T01, *_B01, *_R01, *_P01, *_BR01 | *_T15, *_B15, *_R15, *_P15, *_BR15 |

Os critérios básicos são os mesmos das estratégias anteriores, aplicados ao M15. Não há uma estratégia nova treinada/validada estatisticamente. EUR/JPY/GBP usam tendência H1; CHF_R15 continua a estratégia **separada de lateralização**, com condições de consolidação e estabilidade H1, e não se converte em estratégia de tendência. CHF não usa o módulo de espera por pullback/reteste das estratégias de tendência.

Plan*Timeframe fica preservado nos inputs para voltar ao modo anterior. No paciente ele é sobrescrito somente no perfil efetivo de novas entradas. O timeframe de sinal fica gravado no plano. Posições antigas sem esse novo campo são reconhecidas como sinais M5; continuam usando seu timeframe estrutural, SL/TP, risco inicial e política de saída persistidos. Os handles M5 antigos de gestão foram preservados, separados dos indicadores de entrada paciente.

## Como espera

O scan processa uma vez por nova vela M15. Uma confirmação objetiva já completa no sinal pode aprovar uma entrada imediatamente após o fechamento M15; o modo **não impõe duas horas de espera a toda entrada**. Se a entrada imediata falhar por geometria recuperável, pode agendar WAIT_PULLBACK ou WAIT_BREAKOUT/WAIT_RETEST segundo o módulo habilitado.

EMA20 e invalidação inicial são congeladas no agendamento. O pullback exige toque de uma vela fechada e retomada por outra vela fechada, ambas após o sinal original. No paciente essas são velas M15. Não há confirmação usando preço de vela em formação. Rompimento/reteste, quando habilitado separadamente, também usa fechamentos M15 e um reteste posterior.

`PatientWaitBars=8` significa vencimento quando a idade atingir oito intervalos M15: aproximadamente2h desde a abertura da vela em que o sinal foi registrado. Exemplo: sinal09:00 → antes de11:00 ainda pode confirmar; às11:00 expira. A espera termina antes por invalidação do SL original, perda de tendência/regime, janela de notícias, fim da sessão permitida, mudanças de conta/autorização ou exposição conflitante. Pausa, emergência, desconexão e reconfiguração não são contornadas automaticamente. Reinício cancela pendências.

O parâmetro aceita4–32 candles M15, mas8 é apenas um candidato para teste. A espera não amplia o SL original, não passa por cima do suporte/resistência e não permite preços antigos: a cotação continua tendo que ser recente **no momento de enviar**. Espera maior não é tolerância maior de slippage nem prazo maior para transmitir uma ordem velha. Um candle pulado não é contado como confirmação consecutiva.

As reavaliações antigas a cada10s permanecem desativadas pelo uso de PlanUseEventWaits=true. WAIT_SPREAD continua limitado à vela original, agora M15, para não herdar um sinal vencido por normalização tardia.

## Consequências dos parâmetros em unidades de candle

`RangeBars=12` passa a representar12 velas M15 (3h), enquanto antes representava1h de M5. JPY_B15 e GBP_T15 aguardam essa faixa inicial da sessão mais uma vela de confirmação; não entram imediatamente no início da janela. `PlanMaxStructureAge=12` representa até3h na estrutura M15; StructureLookback60 cobre15h de barras, e HistoryBars250 cobre62.5h de barras. Intervalos de mercado fechado podem aumentar o tempo cronológico. Não selecione retrospectivamente o timeframe que teria vencido.

Os limites financeiros **não aumentam**: stop máximo em pips ou ATR, exposição USD, máximo de duas posições, perda diária, margem, custos e R:R continuam iguais. Em FIXED_NET_USD,5USD e mínimo2R ainda limitam o risco estimado a2.50USD e mantêm saída integral sem parcial/trailing. Stops M15 podem ser maiores e resultar em lote mínimo inviável ou em recusa pelo teto. Portanto o modo paciente pode operar menos; não é um mecanismo para forçar entradas nem uma garantia de ganho.

## Painel, logs e acompanhamento

Painel mostra `Tempo: PATIENT_M15 | Sinal: PERIOD_M15`. No histórico, confira `signal_tf=PERIOD_M15`, `tf=PERIOD_M15`, IDs EUR_T15/JPY_B15/CHF_R15/GBP_T15 e estados de espera com `wait_bars=8`. Logs e snapshots preservam a identidade do sinal; relatório de oportunidades separa os novos IDs dos antigos. Rotação de snapshots permanece independente. Contrafactual opcional usa o timeframe de sinal persistido: horizonte6 agora é6 velas M15 (90min), não6 velas M5; continua hipótese limitada sem fills/carteira reais.

O gráfico pode estar em outro período, pois os indicadores usam timeframes explícitos. Para acompanhar visualmente, prefira gráfico M15; trocar período pode reinicializar/desarmar o EA. Use apenas uma instância por conta/terminal.

## Instalação, comparação e rollback

Sem posições abertas e com Algo Trading desligado:

```powershell
git pull --ff-only origin development/safe-multistrategy
py tools\install_mt5.py "CAMINHO DA PASTA DE DADOS DO MT5"
```

Compile ForexSmart.mq5 com F7, confira v2.16 e zero erros, anexe em demo, configure o bloco inicial e custos, habilite Algo Trading/permissões e clique ATIVAR DEMO. O instalador continua verificando13 fontes; o arquivo local do Telegram é preservado. Mudar parâmetros reinicializa/desarma.

Compare v2.16 STANDARD_M5 com PATIENT_M15 em testes separados, mesmos dados de ticks/custos/risco e sem misturar alterações de RR, valor alvo ou stops. O pacote paciente muda conjuntamente sinal/estrutura/espera; não atribua eventual efeito a apenas um componente. Use período posterior fora da amostra e forward demo; meça operações, custos, R líquido, PF, equity drawdown, duração, rejeições e expirações por estratégia/par. Valide especialmente reinício durante espera e recuperação de posições de versões anteriores.

18 testes Python e cinco harnesses C++ passaram localmente. O novo teste usa as funções compartilhadas para testar ausência de novos sinais nas fronteiras M5 internas ao M15, oito intervalos até expiração, gaps, confirmações separadas e orçamento monetário preservado. Testes de identidade asseguram que os códigos antigos não mudaram e que IDs pacientes têm recuperação consistente. Integridade/backup do pacote e regressões anteriores passaram. **Não houve compilação completa MQL5, backtest no Strategy Tester nem execução demo/real neste Linux.** Esses testes não demonstram rentabilidade ou funcionamento integral da API MT5.

Rollback de novas entradas: EntryTempo=STANDARD_M5. Para rollback exato de código, somente sem posições abertas, commit0070d4e (v2.15), reinstalação de todas as fontes e recompilação. Preserve histórico, credenciais, FSPlan e marcas de duplicidade.
