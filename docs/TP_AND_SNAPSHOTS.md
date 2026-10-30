# v2.12 — extensão condicional de TP e controle de snapshots

## Evidência analisada

CSV de 28/10 08:30 a 30/10 14:00, horário do servidor: 59 sinais, 55 rejeições e 4 execuções automáticas históricas. Dia 30: 22 sinais e 22 rejeições; nenhuma execução nova.

| Rejeição de 30/10 | Quantidade |
|---|---:|
| Obstáculo sem espaço para alvo executável | 9 |
| Espaço técnico não cobre R:R líquido | 5 |
| Sem obstáculo confirmado | 3 |
| Sem pivô adverso confirmado na idade permitida | 2 |
| Stop acima do máximo | 2 |
| SL/TP inválido para cotação | 1 |

No snapshot EURUSD venda 13:15:02, Bid1.11994, Ask1.12004, suporte confirmado1.11990 (12:40), invalidação1.12054 (12:35), ATR Wilder~3,7354pips, buffer2pips e SL1.12084 (9pips). O suporte deixa só 0,4pip de espaço bruto. Convertendo o alvo para Ask e aplicando buffer, o nível1.12020 fica acima da entrada da venda: não é um TP de lucro válido. Aumentar o limite R não autoriza atravessar esse obstáculo.

A mínima do candle13:00 chegou a1.11962, mas o snapshot não apresenta fechamento posterior ao suporte selecionado que comprove seu rompimento conforme uma política definida. Não foi implementado descarte de suportes apenas para obter alvos maiores. Os sinais originais e limites de risco/exposição foram preservados.

## Extensão opcional, sem fabricar espaço

`PlanAllowTargetExtension=false` por padrão; ativação explícita para estudo, somente no TECHNICAL_PLAN. Se o plano inicial passa por execução/risco, mas falha no R:R líquido, a alternativa calcula TP com teto `PlanExtendedTargetMaxR=4`, em vez do `PlanMaxTargetR=3` inicial.

A alternativa usa **o mesmo obstáculo, mesma folga, mesmo SL**, sem ampliar orçamento ou lote; o volume pode somente ficar igual ou menor após revalidação. Mantém MaxTPPoints no LEGACY. Recalcula custos, parcial projetada, margem, risco e R:R. Só seleciona a alternativa se atingir o mínimo líquido. Não altera o TP de posições já abertas. Se o obstáculo já limitava o TP original, a extensão não muda nada e a entrada continua recusada.

O recurso não reduz EUR_RewardR/JPY_RewardR nem promete mais entradas/rentabilidade. No snapshot enviado a extensão não resolveria a rejeição: falta espaço físico, não apenas teto configurado. Não aumentar PlanMaxTargetR ou reduzir buffers sem comparação em backtest. Novos eventos: `plan_target_extension_evaluation`, com TP anterior e indicação de limites mantidos.

## Registro de TP corrigido

TP ainda não calculado agora aparece com `TP_state=NOT_CALCULATED`, TP_pips/RR=N/A. TP do lado errado aparece `INVALID_SIDE`, distância assinada negativa e RR=N/A. Não calcula mais RR positivo artificial com abs() ou TP zerado. Economia ainda não avaliada mantém campos monetários zerados, mas RR líquido=N/A; zero não representa resultado de operação.

Alertas prévios passam de “Oportunidade” para **“Sinal em avaliação”**, pois ainda não são entradas aprovadas. A gravação `signal` mantém seu formato para compatibilidade com ferramentas.

## O que é FSSignal e por que havia tantos

FSSignal é uma fotografia de auditoria de UM sinal: META contém par, estratégia, direção, horários, Bid/Ask, custos/risco/unidades; as 250 linhas BAR são candles fechados do timeframe de planejamento. Não é uma posição, treinamento de IA nem arquivo necessário para o motor negociar. O planejador consulta o mercado no MT5 diretamente.

A v2.10/2.11 tinha `PlanSaveSignalSnapshots=true` e criava um arquivo (~20KB) por sinal, inclusive recusado; não havia retenção automática. O nome inclui escopo da conta/servidor e hash para identificar o sinal. O CSV history é diferente: um arquivo cumulativo com os eventos. FSPlan contém estado de posições e não deve ser confundido com snapshots.

Novos controles:

| Input | Padrão novo | Efeito |
|---|---|---|
| PlanSaveSignalSnapshots | false | Não cria snapshots diagnósticos por padrão; entradas/saídas continuam no history |
| PlanSnapshotMaxFiles | 30 | Limite de snapshots da conta no terminal, quando gravação estiver habilitada |
| PlanSnapshotPruneOldest | false | No limite, pausa só a criação de snapshots; não apaga nada e não altera permissão de trading |

Com PruneOldest=true, consentimento explícito, remove somente os FSSignal mais antigos da conta/servidor até liberar espaço dentro do limite. Não apaga history, FSPlan, arquivos Telegram, outros prefixos ou outra conta. Se um arquivo não puder ser removido, não cria um novo acima do limite. A enumeração/gravação/pruning real precisa ser validada no MT5/Windows; testes de política em C++ não a substituem.

**Inputs já salvos no MT5 podem continuar true após atualizar.** Confira manualmente `PlanSaveSignalSnapshots=false` para interromper a produção. Arquivos existentes não são apagados automaticamente por essa opção. Pode arquivar os FSSignal já coletados fora da pasta operacional, com EA parado, preservando evidências. Não apague a pasta Files inteira, o histórico, credenciais ou FSPlan de posições abertas. Para estudar um problema, habilite temporariamente snapshots e limite sua quantidade. Leia cópias do history para evitar lock do Excel.

## Instalação e testes

Atualizar branch development/safe-multistrategy, desligar Algo Trading e ficar flat; rodar instalador de fontes verificadas, compilar F7 v2.12. Mesmo pacote de nove arquivos. Confirme inputs anteriores em vez de presumir que defaults mudaram. Padrões mantêm planejador anterior e extensão desligada; nenhum merge na main.

Comparar, no testador e depois demo: extensão desligada vs ligada nos MESMOS sinais/custos, verificar que TP nunca ultrapassa obstáculo e que lote/SL/risco não são aumentados. Testar gráfico por gráfico e checar parciais/projeção líquida. Retenção: cap baixo de teste, opt-in de pruning somente em conta demo com snapshots de teste e backup; histórico/credenciais/FSPlan devem permanecer intactos. Não enviar ordens reais nesta tarefa.

Testes locais executados: 12 testes Python e dois harnesses nativos; novas asserções cobrem extensão com espaço, ausência de extensão diante de obstáculo próximo, snapshot fornecido recusado sem TP falso, volume limitado, distâncias assinadas e política de capacidade. Compilação MQL5, extensões executadas, enumeração/remoção de arquivos no Windows e desempenho em backtest não foram executados. Não há evidência de ganho novo nem de melhor frequência.

Rollback: desabilitar PlanAllowTargetExtension; para comportamento de captura antigo, habilitar snapshots, respeitando limite. Rollback de código apenas flat para cee85ee e pacote correspondente, com backup; os campos de plano continuam schema3 compatíveis. Não remover estados de posições abertas.
