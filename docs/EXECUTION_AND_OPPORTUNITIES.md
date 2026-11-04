> Documento histórico da versão2.x, aposentada. Para a versão ativa3.00, use [ML + price action](ML_PRICE_ACTION.md).

# Forex Smart v2.14 — execução e oportunidades em espera

Implementação incremental na branch `development/safe-multistrategy`; main preservada. Nenhuma ordem enviada nesta tarefa. Pacote: EA + 11 includes, 12 fontes verificadas pelo instalador. Requer compilação e validação no MT5 antes de qualquer teste operacional. Não há evidência de vantagem estatística dos módulos novos.

## 1. Evidências e correção do envio

O plano `EURUSD#/EUR_T01/1793622300`, servidor 02/11/2026 12:25:02, passou duas vezes em PrepareTechnicalPlan: entrada 1.12144, SL 1.12231, TP 1.11883, lote .27, risco USD24.03, RR líquido 2.2041. Depois foi descartado sem execução. A versão anterior chamava PrepareTechnicalPlan duas vezes incondicionalmente e registrava duas aprovações. Isso **não comprova duas tentativas de ordem**: nenhuma chegou ao PositionOpen neste caso.

A validação final anterior usava um OR com: candle M5 atual diferente do capturado, tick ausente/antigo, plano com mais de 5s, desvio absoluto maior que SlippageReservePoints, **qualquer aumento do spread**. Este último podia descartar um plano ainda econômico por uma fração de ponto. Não existia comparação de objetos nem igualdade de timestamp de tick. O candle comparado era o M5 em formação capturado pelo Scan, não o horário do candle fechado: essa identidade continua sendo uma proteção válida. O CSV não registrou os operandos da comparação final; não permite atribuir o descarte histórico a uma dessas condições com certeza.

Agora:

- Uma construção estrutural por avaliação; atualizações seguintes preservam o SL e TP técnicos e recalculam entrada, R inicial, lote, custos, margem, risco agregado e RR líquido.
- Sinal fechado/contexto e candle M5 atual continuam válidos; notícia, autorização e permissões continuam obrigatórias. O horário do tick pode mudar normalmente.
- `PlanSendMaxQuoteAgeSeconds=10`, `PlanSendMaxDriftPips=1`, `PlanSendRefreshAttempts=2`. Desvio em pips é uma tolerância de **replanejamento**, diferente da reserva de slippage de execução em pontos. Não autoriza preencher arbitrariamente 1pip pior.
- Cada fase de atualização econômica tem até duas leituras/reavaliações. A persistência pré-envio tem até duas passagens de congelamento; nenhuma chama PositionOpen para tentar obter outro preço.
- Depois da persistência, a cotação deve estar dentro da reserva de execução, dos limites de spread, geometria, custos/risco, margem, orçamento e RR. Falhas registram valores/motivos. Não exige spread idêntico ao anterior.
- `plan_candidate` e `plan_revalidated` são etapas. `plan_accepted` ocorre uma vez por passagem completa de envio. Uma oportunidade reavaliada pode produzir outra aprovação explícita, sem contar como sinal novo.
- Há marca persistente por intenção original, além da marca por símbolo/candle. Nenhuma intenção despachada é retransmitida, inclusive após timeout/conexão incerta. Resposta incerta desarma; a recuperação reconcilia histórico/posições/planos antes de reativação manual. Não existe retry de ordem.

A última janela entre verificações locais e a resposta do servidor é inevitável: a auditoria pós-preenchimento existente continua conferindo risco/preço/SL/TP/RR e pode fechar a posição própria se houver violação.

## 2. Políticas separadas das proteções obrigatórias

Permissões, autorização, dados válidos, SL, orçamento de risco, margem, perda diária, exposição, restrições da corretora, custo extremo e duplicidade continuam obrigatórios. Não existe score que compense falha nesses itens.

Referência preservada: `PlanStopLimitPolicy=FIXED_PIP_LIMIT`. Política opcional `ATR_WITH_ABSOLUTE_CAP`:

```text
limite de distância = mínimo(ATR Wilder14 × máximo ATR do par, PlanAbnormalStopPips × pip)
```

`PlanEURMaxStopATR=6`, JPY=6, CHF=5, GBP=6; `PlanAbnormalStopPips=60`. São valores candidatos para teste, não calibrados. O SL continua vindo de estrutura + buffer + piso de volatilidade; nunca é encurtado para caber. Lote é recalculado para o mesmo risco monetário. Idade do pivô e afastamento do sinal continuam detectando entrada atrasada/estrutura obsoleta. Isso não modela duração esperada estatisticamente; os limites são aproximações explícitas que precisam de validação por duração/estratégia.

`PlanUsePairPivotAge=false` preserva `PlanMaxStructureAge`. Se true, usa `PlanEURPivotMaxAge`, JPY, CHF, GBP, todos inicialmente12 candles do timeframe do perfil. Timeframe M5/M15 e método de confirmação por PlanPivotLeft/Right já existiam e foram reutilizados; não se criou filtro redundante. Os tetos de distância e idade devem ser testados em separado.

`UNBROKEN_CONFIRMED_PIVOTS` acrescenta uma política opcional: mantém pivôs confirmados locais e exclui os rompidos por fechamentos, sem exigir confluência M15. `ALL_CONFIRMED_PIVOTS`, `RETESTED_OR_M15` e `M15_CONFIRMED_ONLY` continuam. As classificações M15_CONFLUENCE e RETESTED_LOCAL são diagnósticos existentes, não novas estratégias ou probabilidades. A seleção usa apenas o nível elegível mais próximo: níveis duplicados não acumulam penalidades, e a borda mais próxima prevalece. Um novo pivô após rompimento pode voltar a constituir obstáculo; não há caminho livre presumido.

Dados fechados insuficientes e M15 indisponível têm motivos próprios. Ausência de nível elegível com dados completos é outra situação. Somente a variante de rompimento/reteste pode, com `PlanBreakVolatilityTarget=true`, testar alvo por múltiplo do R quando não houver outro obstáculo elegível no lookback. Registra `target_source=VOLATILITY_NO_CONFIRMED_LEVEL`, obstacle=0; não inventa nível. Continua exigindo dados completos, SL, RR e custos. Havendo obstáculo, respeita-o. Padrão false.

Não se reduziu o RR de referência: EUR2, JPY2, CHF1.5, GBP2, provenientes dos respectivos RewardR. O planejador técnico também recusa mínimo abaixo de1. Netting sem parcial e hedging com parcial elegível são avaliados conforme a saída real configurada. Exemplo observado .27lote, parcial .13 em1.5R e restante .14 no TP3R: retorno projetado bruto ponderado USD53.505, menos USD.54 de custos =52.965; dividido pelo risco24.03 =2.2041. **3R de TP não são 3R líquidos sobre toda a posição**. Trailing pode fechar antes desse alvo: projeção não é expectativa nem promessa de resultado.

## 3. Estados de espera e módulos independentes

`PlanUseEventWaits=false` mantém as reavaliações antigas. Se true, substitui os retries de segundos por eventos relevantes; PlanEnableSpaceRecheck deixa de agendar novos retries. Fases:

| Estado | Evento / decisão |
|---|---|
| WAIT_PULLBACK | Zona EMA20 M5 congelada; candle toca a zona e outro candle fechado confirma retomada |
| WAIT_BREAKOUT | Conta fechamentos consecutivos além do obstáculo original |
| WAIT_RETEST | Depois do rompimento, aguarda vela posterior que reteste e feche na direção correta |
| WAIT_SPREAD | Reavalia quando spread absoluto volta ao limite, dentro do candle original |
| INVALIDATED | Perdeu tese, contexto, autorização, dados, limites ou plano alternativo recusado |
| EXPIRED | Prazo em candles ou limite de avaliações esgotado |
| APPROVED | Representado pelo evento financeiro plan_accepted; gatilho sozinho não é aprovação |
| SUBMITTED / FILLED | Diferencia tentativa enviada de preenchimento confirmado |

Os módulos estão **desligados por padrão**, só funcionam com MULTISTRATEGY + TECHNICAL_PLAN + PlanUseEventWaits e o sinal original habilitado para aquele par:

- `PlanEnableTrendPullback=false`: IDs EUR_P01, JPY_P01, GBP_P01. Zona inicial é EMA20 M5, tolerância `PlanPullbackZoneATR=.2` × ATR congelado. Um candle fechado toca a zona; a vela seguinte fecha além da máxima/mínima dele, com corpo na direção da tendência e sem excursão adversa além da zona ampliada. Ambos precisam ocorrer após o sinal original. Exige tendência H1, ADX/regime, sessão/calendário e tese ainda válida. Reconstrói todo o plano; não persegue preço sem pullback.
- `PlanEnableBreakRetest=false`: IDs EUR_BR01, JPY_BR01, GBP_BR01. Dois fechamentos novos (`PlanBreakConfirmCloses=2`) além do nível, buffer máximo de `.1ATR` (`PlanBreakBufferATR`) e spread observado. Depois, candle posterior toca a região e fecha novamente além do nível, com corpo na direção da operação. Fechamento de volta pelo lado oposto invalida. Um wick isolado não rompe. Reutiliza o contexto e as primitivas das estratégias existentes, sem copiar um segundo detector GBP_T01.
- Lateralização: `CHF_R01` **já existia**, com EnableCHF_R01 independente, regime CONSOLIDATION, ADX baixo, EMA H1 relativamente estável e retorno às bandas após RSI extremo. Foi preservada; um sinal de tendência rejeitado jamais vira compra/venda de lateralização. Não foi duplicada uma estratégia de faixa sem evidência.

Prazo padrão EUR/JPY/GBP **4 candles M5**; CHF2, configuráveis em Plan*WaitBars (máx6). A oportunidade expira quando a idade atinge o limite. Quatro permite duas confirmações de rompimento e um reteste posterior; configuração incompatível com o número de confirmações é recusada. Em estrutura ausente, a espera pode usar extremos fechados recentes como invalidação da tese, declarada no log; isso **não** serve de SL de ordem: o novo plano ainda exige pivô confirmado.

Uma pendência por símbolo arbitra os módulos. Para falta de espaço com nível conhecido, rompimento/reteste tem prioridade se ambos estiverem ativos; nos outros casos recuperáveis pode aguardar pullback. Novos sinais do mesmo símbolo são suprimidos enquanto essa intenção estiver pendente. O módulo dispara no máximo uma avaliação por nova vela; depois de confirmado e avaliado, a intenção termina se recusada, sem repetição cega a cada10s. Spread é observado por timer, mas só dispara uma avaliação quando normalizado. Outros pares continuam sendo analisados, sujeitos aos limites globais de exposição.

A fila é memória transitória. Reinício, mudança de conta/configuração/geração de autorização, pausa, emergência, desconexão, perda de permissão, invalidação inicial e posições/ordens conflitantes cancelam. Não existe rearme automático. Dados ainda não disponíveis adiam uma verificação; não permitem entrada. Gerenciamento das posições próprias já abertas segue os planos persistidos.

## 4. Medição e coleta

`opportunity_new`, `opportunity_alternative`, `opportunity_trigger`, `opportunity_state`, `plan_candidate`, `plan_revalidated`, `plan_accepted`, `dispatch_committed`, `order_dispatch` e `order_fill` separam as etapas. A intenção original fica persistida no plano, inclusive em módulo alternativo. Uma marca de dispatch comprometida sem envio não é preenchimento.

```powershell
py tools\opportunity_report.py "C:\copia\ForexSmart-...-history.csv" --start 2026.10.30 > funil.json
py tools\plan_report.py "C:\copia\ForexSmart-...-history.csv" > resultados.json
```

O primeiro agrupa sinal/intenção e módulo, primeira e última rejeição, aprovações/envios/fills sem somar retries como sinais. O segundo fornece resultados de posições comprovadamente encerradas: média líquida em R, profit factor, drawdown dos resultados fechados (não equity intratrade), duração e grupos por estratégia/par/regime/hora. Ausência de trades retorna ausência de estatísticas, não lucro hipotético.

Snapshots continuam opcionais (`PlanSaveSignalSnapshots=false`). Nesta versão, `PlanSnapshotPruneOldest=true` é padrão para **rotação de FSSignal desta conta**, até PlanSnapshotMaxFiles30. Não apaga FSPlan, histórico ou Telegram. Se atualizar inputs antigos, confira explicitamente true: o MT5 pode conservar false. False continua disponível para preservar todos os arquivos e interromper apenas a coleta nova no limite. Limite ou falha de snapshot não é permissão financeira; falha do diário obrigatório ainda desarma conforme proteção anterior. Faça cópia dos snapshots importantes antes de habilitar rotação.

`PlanCollectCounterfactual=false`: coleta opcional dos planos rejeitados com geometria e valores econômicos completos. Horizonte pré-definido `PlanCounterfactualHorizonBars=6` velas M5 (máx24), hipótese **entrada na cotação registrada, SL/TP fixos, sem parcial/trailing**, até primeira barreira ou marca ao final do horizonte. Registra counterfactual_start/result; nunca envia ordem.

É diagnóstico OHLC, **não simulação completa da estratégia ou carteira**: spread congelado, conversão monetária no instante de observação e execução presumida. Se a vela de entrada (que inclui segundos anteriores ao sinal) toca uma barreira, resultado AMBIGUOUS_ENTRY_CANDLE e R=N/A. Em velas posteriores com SL e TP tocados, STOP_FIRST. Lacuna de candles dá INCOMPLETE_CANDLE_PATH e R=N/A. Não atribui resultado a TP inválido/SL ausente. Até64 observações em memória; reiniciar interrompe as pendentes. Resultados dessa hipótese não entram nas estatísticas de trades nem provam oportunidade lucrativa perdida. Não há dados futuros retroativamente criados para o CSV enviado.

## 5. Teste em demo e ablação

Com Algo Trading desligado e sem posições, atualize a branch, rode o instalador e compile F7. Confirme v2.14 e **zero erros** antes de anexar. Uma instância; Telegram local preservado. Alteração de inputs desarma: autorize conscientemente ATIVAR DEMO após configurar. Não teste REAL nesta tarefa.

Faça execuções separadas, mesmos ticks reais/spreads/comissões/datas/equity/símbolos e limites de exposição:

| Comparação | Alteração isolada |
|---|---|
| Referência | v2.13, parâmetros arquivados; nenhuma otimização neste curto período |
| A | v2.14, TECHNICAL_PLAN, políticas anteriores, esperas e módulos false: correção de envio |
| B1 | A + ATR_WITH_ABSOLUTE_CAP; sem alterar RR ou política de obstáculos |
| B2 | A + UNBROKEN_CONFIRMED_PIVOTS; teto anterior, sem novos módulos |
| C1 | A + PlanUseEventWaits=true + apenas PlanEnableTrendPullback=true |
| C2 | A + PlanUseEventWaits=true + apenas PlanEnableBreakRetest=true, alvo por volatilidade false |
| C3 | C2 + apenas PlanBreakVolatilityTarget=true |
| Faixa existente | CHF_R01 separada, mesma referência de parâmetros e custos |

Depois, combinações apenas se cada efeito estiver entendido. Seleção em um período de desenvolvimento; avaliação em período cronologicamente posterior não usado na escolha, vários regimes/pares e forward demo. No tester, sessão autorizada exige TesterAuthorizeSession=true; calendário indisponível só pode ser bypassado explicitamente e essa limitação deve constar na comparação.

Inclua testes de reinício/reconexão, ordem ambígua, CSV bloqueado, journal failure, perda de autorização no meio da espera, margem, custo/spread, lote mínimo, exposição manual, limite2, troca de conta e preenchimento fora do preço. Nunca repetir ordem após timeout. Compare expectativa líquida R, PF, equity drawdown do MT5, frequência, custo, duração, rejeições e estabilidade. Fixe antes de testar as regras/horizontes contrafactuais e trate OHLC ambíguo conservadoramente.

Não há neste ambiente MetaEditor/MT5 nem ticks futuros anexados; não foram executados compilação MQL, backtest de carteira, ablação de lucro ou forward demo. Testes locais e auditoria geométrica não substituem essas etapas. **Nenhuma quantidade de operações recuperadas ou melhora de rentabilidade foi demonstrada.**

Rollback de comportamento: módulos/event waits/counterfactual false, FIXED_PIP_LIMIT, PlanUsePairPivotAge=false, política anterior de obstáculos. Para rollback exato de código, somente flat: checkout `15de04c`, reinstale todo o pacote e recompile. Preserve FSPlan/histórico/credenciais e registre os parâmetros anteriores; o instalador guarda backup de fontes e ex5. Não exclua marcas de duplicidade para forçar reentrada.
