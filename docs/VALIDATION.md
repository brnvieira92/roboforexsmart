# v2.00 — auditoria, entrega incremental e validação

## Estado desta entrega

Branch `development/safe-multistrategy`, baseline `97c2283725412e2e23311a6ecabac42aa4a57cd2`. A main remota foi consultada antes das alterações e continuava nesse commit. Não há IA/Random Forest. O motor continua MQL5, sem dependências novas para executar. O C++ é apenas um harness de teste de funções compartilhadas; não executa ordens e não substitui o EA.

**Não aprovado para operação real nem declarado pronto para execução demo: compilação completa e validação no MT5 estão pendentes.** Nenhuma ordem foi enviada nesta tarefa. Compatibilidade REAL é arquitetural, não uma certificação de execução. As estratégias são hipóteses de pesquisa, desabilitadas por padrão.

## Arquitetura preservada

EA M5, magic 2601027, EMA9/21 e ATR14; funções OnInit/Scan/Manage/OnTimer/OnTradeTransaction e painel mantidos. Telegram original não foi substituído. CSV de três colunas mantém o leitor antigo. Cópia exata do EA v1.10 em `docs/baseline/ForexSmart-v1.10.mq5`; compile a baseline com o include Telegram do commit original para comparação.

Novos módulos em `mt5/Include`: Core (fórmulas e permissões testáveis), Account (identidade/equity), Risk (custos e exposição), Recovery (reconciliação), Research (estratégias e calendário). Não há dependências Python obrigatórias na negociação.

## Problemas encontrados e mudanças de segurança

- v1.10 permitia AutoTrade herdado após troca de conta. Agora login, servidor ou tipo novos revogam a autorização; toda reinicialização exige nova ativação. CONTEST não arma. REAL usa exatamente o mesmo motor que DEMO.
- Estado antigo usava login, sem servidor. Agora arquivos e globais usam login + fingerprint de servidor. O CSV antigo fica intacto; não será reatribuído a uma conta por suposição. Chaves antigas de equity/parcial não são importadas cegamente: o histórico da posição da conta atual reconstrói evidência de saída/parcial. A nova referência diária começa na primeira execução da v2 em cada dia.
- Mudança de conta limpa fila Telegram, autorização e referência carregada. Desconexão também desarma novas entradas. Uma reconexão não rearma.
- Lotes são arredondados para baixo e incluem provisão de comissão e slippage. Equity é consultada novamente para cada operação. Uma estimativa de custos precisa de confirmação explícita, pois o MT5 não expõe uma tarifa universal de comissão futura.
- Limites de duas posições/ordens totais, risco agregado de 0,5%, exposição USD na mesma direção, spread absoluto e relativo ao SL, custos/risco, tick antigo, margem com reserva de 10%, especificações e SL/TP contra Bid/Ask. Ordens pendentes ou posições sem SL tornam o risco agregado desconhecido e bloqueiam entradas; não são canceladas automaticamente.
- Lease atômica por conta impede duas instâncias deste EA no mesmo terminal. Não coordena outros terminais, outros EAs nem ordens humanas concorrentes. Use uma instância e conta dedicada.
- Erros de stops/margem no envio e falha de gravação do diário desarmam entradas. Aceite sem execução imediata também exige reconciliação. O limite de desvio é solicitado, não garantia de execução (depende do modo da corretora).
- Trailing LEGACY continua dependente do ATR atual. Acrescentados `management_state` por candle, `trailing_request`, `trailing_ok` e `trailing_reject`. Não foi substituído por uma estratégia supostamente mais lucrativa.
- Netting com histórico misto é intencionalmente excluído da gestão. Parciais continuam apenas hedging. Isso preserva a restrição conhecida da v1.10; não se afirma suporte completo a parciais netting.

## Estados operacionais

| Estado | Novas entradas | Gestão de posições próprias |
|---|---|---|
| AutoTrade=false ou sessão desarmada | Não | Sim, se terminal/conta permitirem |
| Pausado | Não | Sim |
| Emergência | Não; revoga autorização | Sim; não liquida nem remove SL/TP |
| Limite diário/custo/risco excedido | Não | Sim |
| Terminal Algo Trading desligado/desconectado | Não | Não pode modificar/fechar; SL/TP já aceitos permanecem na corretora |
| Troca de conta | Desarma; exige nova ativação | Reconcilia somente a conta atual |
| REAL autorizada manualmente | Sim, mesmas validações | Sim |
| CONTEST | Não | Apenas gestão quando tecnicamente permitida |

Emergência aqui é bloqueio operacional de entradas, não um comando de liquidação. Ao ativar permissões do terminal, a gestão pode voltar a modificar posições existentes mesmo sem autorizar entradas. Não se deve desativar o terminal esperando que trailing local continue funcionando.

## Estratégias de pesquisa

Todas usam candles fechados: H1/M15 shift 1, M5 shift 1/2. Não usam indicadores de candle em formação. Há disponibilidade mínima de buffers e da faixa antes da decisão. O detector classifica alta/baixa/consolidação/volatilidade alta ou baixa/rompimento/transição/NO_TRADE. Filtros de volatilidade e transição não alteram o LEGACY.

| ID | Gatilho | Filtros | Stop/alvo |
|---|---|---|---|
| EUR_T01 | Pullback e retomada EMA20 M5 | EMA50/200 H1; ADX14 M15 >=20 | Maior entre estrutura de dois candles e 1,2 ATR; 2R padrão configurável |
| JPY_B01 | Fechamento fora da faixa inicial da sessão com buffer | Tendência H1; ADX; ATR atual > ATR de 10 candles atrás × 1,1 | Estrutura/1,5 ATR; 2R |
| CHF_R01 | Retorno para dentro de Bollinger20/2 após RSI extremo | ADX M15 <18, inclinação EMA50 H1 limitada por ATR M15 | Estrutura/1,5 ATR; 1,5R |
| GBP_T01 | Candle anterior rompe e atual retesta/fecha favorável à faixa | Tendência H1; ADX M15 >=22 | Estrutura/1,5 ATR; 2R |

A faixa é dos primeiros `RangeBars` candles M5 a partir de `ResearchStartHour`, em horário do servidor, com sessão terminando em `ResearchEndHour`. Não é detecção automática de Londres/DST. Ajuste com o fuso efetivo da XM; os horários padrão 8–20 são hipóteses. Nenhum mapeamento fixo Brasil→servidor é aplicado. Parâmetros de ADX, stop ATR, R, spread e custo/risco são específicos por estratégia. Não há saída na média de Bollinger nesta entrega: CHF usa alvo em R.

Pesquisa usa notícias de alto impacto das duas moedas via calendário nativo. Falha/indisponibilidade bloqueia a pesquisa. No Strategy Tester o calendário não é presumido disponível: `AllowResearchWithoutCalendar=true` é uma escolha explícita de teste, que deve constar do relatório. Não é um backtest validado de filtro de notícias. LEGACY não recebe calendário nem novos indicadores.

Posições novas recebem comentário `FS2:ID` e política persistida por identificador. A gestão de pesquisa usa R inicial persistido (não ATR variável) para trailing a 1R e parcial a 1,5R; TP em R permanece fixo. Se R não puder ser recuperado, mantém proteção do servidor e bloqueia alterações dessa posição, registrando a pendência. Posições LEGACY seguem sua política mesmo quando StrategyMode muda. O histórico/CSV informa net por negócio, não deve ser confundido com win rate de operações consolidadas.

## Custos e capital de referência

`CommissionPerLotRoundTurn` é moeda da conta por lote para entrada+saída. `CommissionEstimateConfirmed=false` bloqueia novas entradas até o usuário conferir a tarifa da própria conta, inclusive quando for zero. Swap é registrado com unidade/modo da especificação e realizado nos negócios; não é prevista uma duração da operação, portanto swap futuro não é deduzido do lote. Stops, point, tick size, volume/step/max, margem e preços são consultados. `OrderCalcProfit` incorpora contrato/conversão; spread entra pelos preços de execução e não é somado uma segunda vez à perda até SL. Para filtrar custos, o spread é comparado ao risco; isso não é outra cobrança monetária.

`UseReferenceCapital=false`, `ReferenceCapital=50` por padrão. Apenas DEMO usa equity virtual: referência + variação da equity da conta inteira desde a ativação, neutralizando depósitos/créditos. Inclui operações humanas e posições abertas. Não cria dinheiro disponível: usa o menor entre virtual e equity real. REAL sempre utiliza equity efetiva, mesmo com input herdado true. Referência e equity normais têm referências diárias separadas. Se alterar ReferenceCapital após criar o estado, o cálculo bloqueia até reset deliberado dos globais `.ref.*` e `.dr.*`, com EA removido e conta flat, via F3; preserve/exporte estados antes. Não resete para contornar perdas.

## Evidência executada nesta tarefa

- Harness C++ compila o próprio `ForexSmartCore.mqh`, não uma reimplementação Python: sinais LEGACY, stop inicial, TP em mil cenários, gatilhos das quatro estratégias, regimes, 128 combinações de permissões, mudança de login/servidor/tipo e reinício, risco de 0,25%, arredondamento de lote, capital virtual, limite diário e monotonicidade do trailing. Compilado com `-Wall -Wextra -Werror`, executado com sucesso.
- Quatro testes Python de CSV, rejeição de corrupção/valores não finitos, métricas por estratégia e deduplicação passaram.
- `git diff --check` passa.

Esses testes NÃO validam iMA/iATR/iADX no MT5, execução, lifecycle do terminal, seleção de posições, painel, calendário, APIs de persistência ou rede. Não se declara compilação MQL5 aprovada com base no C++.

## Matriz pendente no MT5

1. Compilar v2, baseline e scripts de testes no MetaEditor; zero erros. Teste Telegram existente: codificação/fila; testar envio demo e falha controlada de rede.
2. Backtest ticks reais, mesmas datas/depósito/custos/símbolos para baseline, LEGACY v2 e cada estratégia individual. Salvar `.set` localmente e relatório HTML. Separar cronologicamente desenvolvimento, validação e teste final. Não selecionar parâmetros pelo teste final.
3. Para v2: AutoTrade=true, TesterAuthorizeSession=true. Esse último é ignorado em conta conectada e só autoriza a simulação. Não autoriza REAL. MULTISTRATEGY requer habilitar uma estratégia e declarar escolha sobre calendário ausente. Não usar zero operações como aprovação.
4. Comparar saldo/equity, drawdown, PF líquido, acerto por posição consolidada, expectativa, ganho/perda médios, custos, pares/sessões, quantidade de rejeições e estabilidade dos parâmetros. Nenhum novo backtest foi executado nesta tarefa; nenhum resultado financeiro foi inventado.
5. Demo: lote mínimo, moedas de conta, spread alto, freeze/stops, margem insuficiente, preenchimento parcial, requisição aceita sem fill, ordens pendentes, limite de duas posições, exposição USD, risco agregado, risco diário e reinício.
6. Gestão: preços favoráveis e adversos, ATR crescente/decrescente, SL sem recuo, confirmação/rejeição da modificação, parcial única e recuperação depois de falha. Confrontar CSV com histórico do terminal.
7. Contas: demo A→demo B→servidor diferente e reinício com AutoTrade=true devem ficar desarmados; troca de tipo REAL por mocks apenas nesta etapa. O harness não substitui testes do lifecycle MT5. Não enviar ordens reais.
8. Recuperação: abrir posição v1.10 demo, migrar, verificar histórico antigo intacto, parcial não repetida, posição fora da lista gerenciada mas sem novas entradas nesse símbolo, mudança de StrategyMode não altera política; mistura netting é bloqueada.
9. UI: painel legível, botões pausa/status/ativar/emergência, REAL vermelho quando autorizado; Algo Trading desligado, desconexão, Telegram inválido e histórico indisponível. Nenhuma desativação remove stops.

## Operação e rollback

Compilação: copie `mt5/ForexSmart.mq5` para `MQL5/Experts/` e **todos os arquivos** `mt5/Include/*.mqh` para `MQL5/Experts/Include/`. Os scripts ficam em `MQL5/Scripts/`. F7 no EA. Sem certificado de compilação nesta entrega.

Demo: uma instância M5, símbolos corretos, configuração LEGACY primeiro, confirmar comissão, AutoTrade=true e permissões MT5. Conferir DEMO no painel e clicar ATIVAR DEMO. Alterações de inputs/reinício exigem ativar outra vez. Estratégias de pesquisa permanecem desligadas até decisão explícita após validação.

Futuro REAL: mesmo EA, sem recompilar. Desativar Algo Trading antes de trocar login; conferir símbolos, tipo e moeda, risco e comissão da conta. AutoTrade herdado não basta. Após validação e decisão do usuário, permissões e clique ATIVAR REAL autorizam a sessão. Não realizar esse teste com ordens reais nesta tarefa.

Rollback: desarmar entradas e aguardar ficar flat antes de trocar versão; exportar histórico/estados/configuração. No checkout, `git switch --detach 97c2283`, copiar EA e include Telegram originais, compilar e manter AutoTrade=false ao anexar. A v1.10 não tem as proteções novas de sessão e pode negociar com AutoTrade=true herdado. Não apagar os CSVs nem globals novos. Ao voltar à v2, recompile e reative manualmente. Não misture duas versões simultâneas com o mesmo magic.
