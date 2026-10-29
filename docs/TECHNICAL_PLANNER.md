# v2.10 — planejamento técnico opcional e reversível

## Estado e evidências

A branch de desenvolvimento foi auditada no commit `ad43e8e` (v2.02); a main continua na v1.10. Nenhum AGENTS.md foi encontrado na busca do workspace. Não há dependências novas para o EA e o motor continua MQL5. Não foram enviadas ordens nesta tarefa.

**Entrega de engenharia para revisão, sem aprovação de desempenho:** compilação completa MQL5, APIs de arquivo/calendário/corretora, recuperação do terminal, replay histórico e execução demo permanecem pendentes. Nenhum teste financeiro foi inventado. O planejador anterior continua padrão (`EntryPlanner=PREVIOUS_PLAN`). Ativar TECHNICAL_PLAN é uma escolha experimental explícita. Não habilitar em conta real antes de validação independente.

O CSV fornecido contém quatro entradas e quatro negócios de saída automáticos, sem parciais registradas; a solicitação os identifica como operações encerradas:

| Par/direção | Entrada | SL registrado | Distância | Lote | Líquido registrado |
|---|---:|---:|---:|---:|---:|
| USDJPY compra | 157.987 | 157.933 | 5,4 pips | 0,67 | −24,61 USD |
| EURUSD venda | 1.11422 | 1.11500 | 7,8 pips | 0,30 | −23,40 USD |
| USDJPY compra | 157.959 | 157.807 | 15,2 pips | 0,25 | −24,08 USD |
| EURUSD venda | 1.11604 | 1.11673 | 6,9 pips | 0,34 | −23,46 USD |

Total dos negócios automáticos: **−95,55 USD**, sem duplicar as linhas descritivas. Operações EXTERNAL/Humana foram excluídas. Os stops já variam e os lotes já se adaptam. Quatro perdas não provam a causa, nem demonstram que aumentar stops produzirá vantagem. O CSV tem 37 sinais, 33 rejeições, 4 registros de execução e 21 snapshots de gestão, sem `trailing_ok`, `trailing_reject` ou parcial. Na primeira venda EURUSD os snapshots mostram avanço de até 5,5 pips contra gatilho de 7,8 pips: isso é amostragem, não MFE tick a tick.

O histórico antigo não contém TP inicial, ATR de entrada, pivôs/obstáculos ou motivo oficial da saída. `trigger` é gatilho de gestão e `partial_trigger` é gatilho de parcial — nenhum é TP final. Não foram reconstruídos por suposição. A saída USDJPY a 157.929 fica além do SL registrado, mas o motivo oficial da corretora não pode ser inferido desse fato. Sem ticks, não é possível dizer se uma alternativa teria atingido o TP antes do SL, nem medir o ruído de forma contrafactual.

## Auditoria da versão anterior

Sinais preservados: LEGACY EMA9/21 e ATR14 nativo no M5, retomada da média; pesquisa usa EMA50/200 H1, ADX14 M15, EMA20/Bollinger/RSI M5, rompimento/reteste e faixa inicial de sessão. Os filtros de sessão/notícias/regime e as regras por par não mudaram.

SL LEGACY = maior entre 1,5 ATR e mínimo da corretora; pesquisa = maior entre multiplicador ATR e estrutura dos dois candles recentes, com alvo inicial em múltiplo R. LEGACY TP = clamp(ATR × (1+2×força), MinTPPoints, MaxTPPoints). Não existia um piso explícito de R:R líquido; a pesquisa tinha múltiplos brutos configuráveis (2R ou 1,5R). O novo modo não será apresentado como se esse filtro líquido já existisse.

Lote anterior: orçamento = equity relevante × RiskPercent /100; perda por lote via OrderCalcProfit entre entrada executável e SL, mais comissão e reserva de slippage; volume arredondado para baixo e validado contra mínimo, margem e limites. Não há risco fixo de 24 USD. Para pares JPY e conversão de moeda, o EA continua usando OrderCalcProfit, não uma constante de US$10/pip.

Gestão antiga: pesquisa guarda R inicial; trailing a 1R e parcial a 1,5R, apenas hedging. LEGACY usa ATR atual, incluindo TP adaptativo. Recuperação usa accountScope, globals e histórico por posição; posições humanas não são gerenciadas. Telegram/painel/autorizações/magic 2601027 foram mantidos.

## Nova sequência, somente TECHNICAL_PLAN

1. Gerar o sinal original. Não introduzir pontuação, IA, martingale nem meta diária/monetária.
2. Definir invalidação por pivô adverso confirmado em candles fechados, estrutura e ATR Wilder14.
3. Construir SL com buffer, piso de volatilidade e execução; rejeitar se exceder máximo operacional.
4. Determinar alvo disponível antes de obstáculo confirmado, sem extrapolá-lo para satisfazer R:R.
5. Calcular lote somente depois do SL final e verificar custos, orçamento, exposição, risco agregado e margem.
6. Calcular ganho líquido previsto e R:R líquido, incluindo projeção da parcial quando executável; rejeitar se insuficiente.
7. Recalcular cotação/plano/lote/custos antes do envio; descartar se mudou o candle, cotação envelheceu, spread aumentou ou entrada se afastou além da reserva entre avaliação final e envio.
8. Persistir plano pendente antes de enviar uma única ordem. Após execução, reconciliar pelo order/deal/position e conferir risco e proteções efetivos.

US$5 e US$10 não são inputs nem gatilhos. O ganho estimado decorre do lote permitido e do espaço técnico, na moeda da conta. Uma posição que arrisca 24 para tentar ganhar 5 não passa por uma regra mínima de R:R >=1. Não existe probabilidade individual de acerto, nem promessa de precisão.

## Critérios determinísticos e parâmetros

Todos os perfis novos têm timeframe predefinido M5; `PlanEURTimeframe`, `PlanJPYTimeframe`, `PlanCHFTimeframe`, `PlanGBPTimeframe` aceitam apenas M5 ou M15. Escolher antes dos testes; não selecionar por operação o timeframe que teria funcionado melhor.

- `PlanHistoryBars=250` (mínimo 200): leitura exclusivamente `CopyRates(..., shift=1)`. A ordem temporal e o fechamento dos candles são conferidos.
- ATR Wilder14: seed = média dos 14 primeiros TR da amostra antiga, seguido por `(anterior×13+TR)/14` até o último candle fechado. É explícito e reprodutível, sem presumir que iATR nativo use a mesma implementação. Os sinais continuam com seus indicadores antigos.
- Pivô: extremo estrito maior/menor que `PlanPivotLeft=2` candles anteriores e `PlanPivotRight=2` posteriores, todos já fechados no instante da decisão. Candidatos sem confirmação são excluídos. Empates não formam pivô.
- Invalidação: pivô adverso confirmado mais recente, do lado correto da entrada, com idade máxima `PlanMaxStructureAge=12` candles. `PlanStructureLookback=60` limita a busca de estruturas/obstáculos.
- Obstáculo: pivô confirmado mais próximo à frente do preço dentro do lookback. Ausência de estrutura ou de obstáculo rejeita a entrada; não significa caminho livre infinito. Rompimentos JPY/GBP mantêm seus sinais específicos e só recebem essa prova adicional de viabilidade.
- `Plan*ATR=1.5`: candidato inicial; comparar 1,5 e 2,0, não considerar aprovado. `Plan*BufferPips=2`: candidato; comparar 2 e 3 pips. Buffer final = maior entre buffer em pips, `PlanBufferATR=0.1 × ATR` e `PlanBufferSpread=1 × spread`.
- `PlanMinStopPips=0`: não impõe piso fixo em pips. Para estudo EURUSD pode-se testar piso de 12 com máximo 20 em configuração separada, sem impor a outros pares. Máximos candidatos por perfil: EUR20, JPY30, CHF25, GBP30 pips. Se exceder, rejeita; **nunca encurta o stop**.
- `PlanMaxTargetR=3`: limite superior de distância do alvo; ainda exige obstáculo real. LEGACY mantém também o teto MaxTPPoints. Não se amplia além do obstáculo para atingir o R:R.
- R:R mínimo novo: pesquisa mantém pelo menos o múltiplo configurado por estratégia, agora líquido; LEGACY usa a razão alvo/stop da política anterior no sinal como piso de comparação. Isto é um novo filtro no modo experimental, não uma alegação de equivalência estatística entre políticas.
- `PlanMaxEntryDriftATR=0.5`: rejeita preço Bid afastado do fechamento que originou o sinal. Configuração de pesquisa, não tolerância comprovadamente ótima.

## Bid, Ask, pip, point, tick e custos

A nova política só aceita símbolos com candles Bid (`SYMBOL_CHART_MODE_BID`). Compra entra no Ask e SL/TP dispara no Bid. Venda entra no Bid e SL/TP dispara no Ask. Máxima estrutural Bid de uma venda é convertida para preço Ask pelo spread contemporâneo, mais buffer; alvo Bid de venda recebe a mesma conversão para Ask. Isso trata a base de disparo, não soma outra tarifa de spread.

SL compra é arredondado para baixo no tick; SL venda para cima. TP compra para baixo, TP venda para cima, sem ultrapassar obstáculo menos folga. Mínimo operacional usa stops_level/freeze_level + dois points, de forma conservadora. Pip = 10 points em FX com 3/5 casas, 1 point em 2/4; sufixos # não alteram a unidade. O novo plano não é destinado a índices/metais/contratos de outra convenção sem adaptação explícita.

OrderCalcProfit calcula ganho/perda na moeda da conta. Spread já entra nos preços executáveis, não é somado de novo à perda monetária até SL; ele também participa dos filtros de custo/risco e do buffer. Comissão é a estimativa round turn confirmada. Reserva de slippage vem de SlippageReservePoints. `PlanSwapReservePerLot=0` permite provisão adicional na moeda da conta, somente no modo novo; zero significa **não estimado**, não conta isenta. Swap futuro continua incerto porque duração/rollover são desconhecidos. Custos reais ficam nos negócios de saída/entrada.

Teste numérico obrigatório executado em código compartilhado: EURUSD, contrato100000, orçamento23,46 USD, stop15 pips, sem custos extras: perda/lote150 USD; lote bruto0,1564; lote final0,15; perda22,50 USD. Outros pares/conversões continuam dependentes do MT5, não desse exemplo fixo.

A projeção de saída considera a parcial apenas se hedging, lote mínimo/step permitirem e TP estiver além do gatilho. Projeta lucro da parte a `PlanPartialR` e restante no TP, deduzindo custos da posição inteira. Trailing/slippage podem antecipar ou piorar saídas; o ganho projetado não é garantido nem uma estimativa de expectativa estatística.

## Persistência, execução e proteção

Arquivos `FSPlan-<accountScope>-<position>.csv`, schema3, guardam plano, estratégia, versão, entrada solicitada/efetiva, SL/TP iniciais, R imutável, lote, orçamento, custos, estrutura/timeframe/horários, política de saída e parâmetros de gestão. A gravação usa temporário + FileMove; falha de persistência bloqueia novas ordens. Plano pendente por símbolo é salvo antes do envio e associado por order/comment à posição, nunca por símbolo apenas. Arquivos são isolados por login/servidor. Nenhuma credencial é incluída.

Após fill, verifica SL/TP no servidor, desvio adverso, orçamento, R:R projetado líquido, margem e risco agregado. Em violação: **desarma novas entradas e tenta uma única vez encerrar a posição própria afetada**, registrando resposta. Não afasta SL, duplica entrada nem promete limitar perda durante gaps. Se o fechamento falhar, permanece desarmado; não se presume encerramento. Posição já encerrada não recebe outra ordem. Arquivo ausente na recuperação causa bloqueio e preservação dos stops do servidor, sem reconstrução especulativa.

Posições abertas antes da atualização mantêm a gestão anterior. Novas técnicas usam comentário FS3 e marca persistida de versão; mesmo voltando EntryPlanner para PREVIOUS_PLAN, essas posições continuam seguindo seu próprio plano. Não remova os arquivos de estado com posições abertas. Mistura netting continua excluída da gestão; parciais só hedging. O filtro USD ainda inclui operações humanas; não foi removido por ter bloqueado sinais anteriores.

## Gestão sem anular invalidação

`PlanExitPolicy=PARTIAL_AND_TRAIL` padrão candidato: trailing somente após `Plan*TrailR=1.5` de avanço e pivô confirmado novo que permita melhoria do SL. `CONFIRMED_STRUCTURE` segue esse pivô com buffer. Alternativa `VOLATILITY_WITH_STRUCTURE` usa ATR e também respeita a estrutura mais conservadora. SL nunca é afastado; TP protetivo não é removido. `PlanPartialR=1.5`, parcial única e executável conforme step/min. Saídas já no histórico impedem repetir parcial após reinício.

`FULL_TECHNICAL_TARGET` é comparação separada: mantém SL/TP do servidor, sem trailing/parcial. Parâmetros não são declarados universais: cada par tem multiplicador, timeframe, buffer, máximo de stop e gatilho de trailing próprios. Alterações não justificam apertar stops antigos.

MFE/MAE são **amostrados** pela gestão a cada ciclo (normalmente 2s) e no preço de saída, não extremos completos de ticks. Quando Algo Trading/conexão impede gestão, a amostragem fica incompleta. Não apresentá-los como MAE/MFE exatos nem como replay histórico.

## Auditoria e ferramentas

`plan_geometry`, `plan_evaluation`, `plan_fill`, `plan_trailing_ok/reject`, `plan_partial`, `plan_exit`, `plan_critical` e rejeições carregam plano/posição e medidas. `plan_exit` registra motivo oficial `DEAL_REASON`, duração, resultado acumulado e R após custos. A parcial não é tratada como encerramento total. Logs registram decisão e execução, sem classificar automaticamente lucro como decisão certa ou perda como errada.

Com `PlanSaveSignalSnapshots=true`, cada sinal gera `FSSignal-*.csv` com metadados e candles fechados do perfil, mesmo em PREVIOUS_PLAN. Guarda Bid/Ask, equity, custos, unidades, timezone SERVER, UTC observado do terminal e origem do relógio (tester não é UTC histórico confiável). Esses snapshots ajudam replay futuro; não substituem ticks/cotações de conversão ou especificações históricas completas. Desative se o custo de I/O interferir no terminal após medição.

```powershell
py tools\plan_report.py "C:\caminho\historico.csv"
```

Relatório separa EXTERNAL, deduplica deal IDs e linhas descritivas, lista rejeições e saídas finais explícitas schema3. Não inventa fechamento completo quando só existe DEAL_ENTRY_OUT (que pode ser parcial) em histórico antigo. O leitor foi ajustado para descrições MT5 com ponto e vírgula não escapado.

## Testes executados e pendências

Executados no Linux: 12 testes Python (histórico, relatório, separação humana/automática, deduplicação, instalação/backup/manifesto); harness nativo anterior; harness novo usando o próprio ForexSmartPlanMath.mqh com compra/venda, 3/5 casas, tick orientado, Wilder, confirmação/idade de pivô, ausência de obstáculo, spread convertido uma vez, stop máximo rejeitado, orçamento/lote mínimo e exemplo23,46→0,15→22,50, custos/R:R, parcial projetada e SL que não recua. Não há mocks de lucro JPY apresentados como verdade de corretora.

Incluído script MQL5 `TestForexSmartPlan.mq5`, sem ordens nem rede: **ainda não compilado/executado**. C++ não valida o adapter MQL5, API de arquivos, OrderCalcProfit/Margin, múltiplos preenchimentos, recuperação, calendário, painel e lifecycle do terminal. Esses casos exigem MetaEditor e testes demo. Não se declara aceitação operacional concluída.

## Protocolo de comparação e dados faltantes

A. Replay dos mesmos sinais: congelar parâmetros de sinais, coletar snapshots + ticks, especificações/conversões históricas e custos; aplicar PREVIOUS, estrutura+1,5 e estrutura+2 ao mesmo universo de sinais, sem bloquear uns porque outra variante abriu posição. Definir previamente horizonte de 24 candles M5 para estudo de ruído (hipótese explícita); comparar alvo original e invalidação alternativa em ticks, não estender horizonte depois de ver resultado. Sem TP original/ticks das quatro perdas, essa análise não foi executada.

B. Simulação completa: Strategy Tester ticks reais por variante, respeitando ocupação/exposição/margem, fechamento, sessões e notícias. Mesmo depósito/datas/conta/spreads/comissão, calendário ausente declarado conforme configuração existente. Separar cronologicamente desenvolvimento, validação e teste final. Comparar expectativa líquida em R, PF líquido, drawdown equity, duração, frequência, rejeições, custos, MAE/MFE ticks, por par/estratégia/sessão. Não selecionar pelo win rate isoladamente. Se só OHLC tiver stop e alvo na mesma vela, marcar ambiguidade e usar stop primeiro no cenário conservador, sem alegar ordem conhecida.

Não há esses dados nem MT5 no ambiente desta tarefa; portanto **nenhuma vantagem do novo planejador foi comprovada**. Manter PREVIOUS por padrão. Após instalar/compilar, começar com simulação, não conta real. Avaliar sensibilidade (buffers2/3, ATR1,5/2 e EUR piso12–máximo20 em ensaio separado), sem ajustar somente às quatro perdas.

## Instalação, demo e rollback

1. Atualizar branch de desenvolvimento, desligar Algo Trading e ficar flat antes de instalar.
2. `py tools/install_mt5.py "PASTA DE DADOS DO MT5"` copia EA + oito includes (nove arquivos), verifica SHA-256 e faz backup sem tocar nas credenciais Telegram. Ou copiar todos manualmente.
3. F7 no MetaEditor. Confirmar v2.10 e zero erros; esta tarefa não obteve esse resultado no MT5.
4. Simular PREVIOUS primeiro. Depois TECHNICAL_PLAN com um par/estratégia por vez e parâmetros fixos. TesterAuthorizeSession=true só no testador; no gráfico permanece false. Conta DEMO, autorizações e confirmação de comissão continuam necessárias.
5. Para operação demo após revisão dos testes: AutoTrade=true, ATIVAR DEMO, registrar Status e acompanhar plano/execução no CSV. Não alterar conta ou enviar ordens reais nesta tarefa.
6. Rollback de política: EntryPlanner=PREVIOUS_PLAN, confirmar inputs e reativar manualmente a demo. Posições FS3 existentes mantêm gestão técnica enquanto houver código v2.10 e arquivos de plano.
7. Rollback de código: aguardar ficar flat, preservar CSV/estados; `git switch --detach ad43e8e`, reinstalar pacote v2.02, compilar. Não trocar para código antigo com posições FS3 abertas, pois ele não conhece essa gestão. Não eliminar o histórico nem os arquivos novos.


## Arquivos alterados

- `mt5/ForexSmart.mq5`: seleção/inputs do planejador, sequência de planejamento/envio, roteamento de gestão por versão e auditoria de negócios, sem mudar fórmulas dos sinais.
- `mt5/Include/ForexSmartPlanMath.mqh`: políticas puras de Wilder, pivôs, geometria, unidades e risco/retorno.
- `mt5/Include/ForexSmartPlanner.mqh`: adapter MT5 de planejamento, snapshot, persistência, pós-fill, gestão/recuperação e auditoria de saída.
- `ForexSmartRisk.mqh`: reserva de swap opcional no novo modo, lote pela política compartilhada e reserva técnica no risco agregado.
- `ForexSmartAccount.mqh`/`ForexSmartRecovery.mqh`: contexto de plano na rejeição, reset de identidade e recuperação por versão.
- `mt5/manifest.json` e teste do instalador: pacote consistente v2.10 de nove arquivos.
- `tests/native/test_plan.cpp`, `mt5/Scripts/TestForexSmartPlan.mq5`: testes de políticas compartilhadas; o script MT5 não foi executado no Linux.
- `tools/history_report.py`, `tools/plan_report.py`, `tests/test_plan_report.py`: leitura compatível e auditoria de resultados, sem duplicar dinheiro; estatísticas das saídas schema3 são descritivas, drawdown de resultados fechados não é drawdown de equity.

A captura de snapshots é opcional, não muda o sinal. O preço é relido depois da captura para não planejar a política anterior com a cotação anterior ao I/O. A compilação e a medição de latência real continuam pendentes no MT5.
