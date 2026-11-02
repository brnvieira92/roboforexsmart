# v2.15 — TP em US$ líquidos estimados e stop estrutural

Modo opcional, sem mudar as estratégias que encontram sinais. `PlanTargetMode=STRUCTURAL_TARGET` preserva o comportamento anterior. Para uma posição nova com alvo monetário:

```text
StrategyMode    = MULTISTRATEGY
EntryPlanner    = TECHNICAL_PLAN
PlanTargetMode  = FIXED_NET_USD
PlanNetProfitUSD = 5.0
```

Somente conta cuja moeda seja USD; não interpreta5BRL/EUR como5USD. Se selecionar o modo em conta de outra moeda ou com PREVIOUS_PLAN, a inicialização é recusada. Comissão estimada deve estar confirmada, mesmo se zero. Novos inputs ficam próximos de EntryPlanner. Módulos de pullback/reteste e respectivas autorizações continuam independentes.

## Como calcula

1. Valida o sinal, dados fechados e pivô confirmado no timeframe do perfil (M5/M15). Para compra, usa a mínima do pivô de suporte menos buffer; para venda, máxima do pivô de resistência mais buffer e conversão Bid→Ask. Respeita distância mínima da corretora e PlanMinStopPips, se configurado. Neste modo **não aplica o piso de distância cfg.multiplier×ATR** do planejador anterior: o stop é estrutural. ATR ainda participa do buffer, filtro de atraso e teto por ATR, se selecionado. Nunca encurta o stop para caber no orçamento; nunca o afrouxa depois.
2. Usa orçamento de risco `mínimo(equity×RiskPercent, meta líquida/RR mínimo)`. Por exemplo: meta5USD e mínimo2R → até2.50USD de risco estimado. CHF com mínimo1.5R → até3.3333USD. Os mínimos por estratégia continuam vindo de EUR/JPY/CHF/GBP_RewardR.
3. Calcula o lote com OrderCalcProfit, custos e arredondamento para baixo ao volume_step. Se até o lote mínimo ultrapassar o orçamento, recusa. Não aumenta risco para conseguir operar.
4. Busca por bisseção o TP na grade de preços da corretora, usando OrderCalcProfit com o lote real. O ganho bruto precisa cobrir5USD + comissão round-turn estimada + reserva de slippage + PlanSwapReservePerLot, quando configurada. Spread já está embutido nos preços executáveis; não é subtraído duas vezes.
5. Escolhe o preço mais próximo que atinja **pelo menos a meta estimada**, podendo excedê-la em até o valor de um tick pelo arredondamento. Antes do envio, uma variação de cotação de até um tick monetário ao redor da meta é tolerada, sob todos os limites econômicos. Se necessário, recalcula TP/lote nas atualizações limitadas pré-envio; SL continua o mesmo e plano persistido recebe o TP atualizado.
6. TP precisa ficar antes do obstáculo validado, com clearance. Se5USD exigirem atravessá-lo, recusa com `TP monetário ultrapassaria obstáculo`, incluindo maximum_net_USD. Dados ausentes ou falta de obstáculo não significam caminho livre. Mesmo a variante de rompimento sem próximo nível não usa alvo por volatilidade neste modo.
7. Antes do envio, repete checagens de risco, margem, custos, R:R, exposição, quote/sinal, idempotência e meta monetária. Auditoria pós-fill anterior continua protegendo execução adversa. Não envia novas ordens para corrigir uma resposta incerta.

Para preservar o objetivo para **a posição inteira**, o plano novo usa `FULL_TECHNICAL_TARGET`: sem parcial e sem trailing. Os inputs PlanExitPolicy/PlanTrailPolicy não prevalecem sobre isso no modo monetário. Se fechar manualmente ou o SL for atingido, não existe promessa de5USD. PlanMaxTargetR, PlanAllowTargetExtension e PlanExtendedTargetMaxR não escolhem o preço do TP monetário: a meta em USD substitui esses multiplicadores, mas não o obstáculo. Limites de stop, custo, risco e exposição continuam válidos.

## Exemplo fictício em EURUSD / conta USD

Entrada compra1.10012, SL estrutural1.09892 (12pips), lote mínimo/step.01, contrato100000, comissão0 e reserva de slippage2pontos. Perda por lote até o SL120USD, reserva2USD/lote. Orçamento5/2=2.50USD → lote.02, risco estimado2.44USD. Ganho bruto necessário5.04USD → distância25.2pips → TP1.10264. Ganho líquido projetado5USD e RR2.049. Só aprova se houver espaço até um obstáculo além desse TP mais clearance e todas as verificações passarem. Os valores são exemplo matemático, não cotação ou indicação de entrada.

Exemplo contrário: stop30pips com lote mínimo.01 gera risco estimado3.02USD, maior que2.50USD. A entrada é recusada. Diminuir lote abaixo do mínimo da corretora ou mover SL para dentro da estrutura não é permitido.

Os5USD são **uma projeção**, não ganho garantido nem valor realizado exato. Slippage, gaps, comissões/swap efetivos, conversão cambial dos pares USDJPY/USDCHF e intervenção manual podem alterar o resultado. Reserva de swap zero significa custo futuro não estimado. O risco de2.50USD também é estimado; gaps podem excedê-lo.

## Logs, persistência e teste

PlanSummary e evento `cash_target` registram target_mode, cash_goal, lot, risk, budget, TP e net_gain. Plano persiste modo/meta/SL/TP/saída por posição; posições antigas conservam suas políticas. Alterar input não converte posições abertas em alvo monetário. Reinício não apaga o plano nem rearma sessão.

Atualize a branch development/safe-multistrategy, desligue Algo Trading e faça a instalação somente sem posições abertas:

```powershell
git pull --ff-only origin development/safe-multistrategy
py tools\install_mt5.py "CAMINHO DA PASTA DE DADOS DO MT5"
```

Compile ForexSmart.mq5 com F7 e confira v2.15, zero erros. O pacote tem13 fontes verificadas (EA +12 includes). Depois configure o modo/meta acima em demo, confira seus custos e estratégias, habilite Algo Trading/permissões e ATIVAR DEMO. Alteração dos parâmetros reinicializa/desarma a sessão.

Teste compra/venda nos quatro pares, tick/volume mínimo, obstáculo próximo, lote mínimo acima do orçamento, spread anormal, reinício e permanência das posições antigas. Compare o objetivo líquido registrado e o resultado efetivo, sem confundir reserva estimada com comissão cobrada. Faça backtest com ticks reais/custos e forward demo antes de considerar conta real.

Testes locais nesta entrega:16 testes Python de regressão/instalação; quatro harnesses C++ com -Wall -Wextra -Werror. O novo harness compila as próprias funções de busca do cabeçalho MQL, com adaptadores de OrderCalcProfit/contrato e grade. Cobre buy/sell, conversão monetária monotônica não linear, entrada fora da grade, arredondamento mínimo, obstáculo sem espaço, moeda incompatível, cálculo indisponível, risco limitado a meta/RR, stop estrutural e lote mínimo inviável. Isso não é integração com a API da corretora nem compilação completa MQL5. MetaEditor, backtest e ordens demo/reais não foram executados neste Linux.

Rollback: PlanTargetMode=STRUCTURAL_TARGET para posições novas. Para rollback de código, somente sem posições abertas: commit bda930e, instalador completo e recompilação. Não apague FSPlan, marcas de dispatch, credenciais ou histórico para forçar reentradas.
