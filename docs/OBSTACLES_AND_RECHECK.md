# v2.13 — relevância dos obstáculos e reavaliação limitada

## O que foi preservado

Mesmo motor MQL5, magic2601027, sinais originais, autorizações DEMO/REAL, seleção de estratégia e planejador anterior, stop/lote/custos/retorno líquido, filtros de sessão/notícias/exposição e gestão das posições existentes. Nenhuma ordem enviada no desenvolvimento. Sem merge na main. A mudança não garante lucro nem mais entradas.

## Obstáculos: pivô não significa automaticamente suporte forte

No TECHNICAL_PLAN o evento `obstacle_review` informa timeframe efetivo do perfil, idade em candles (selected_index), número de toques separados, período entre primeiro/último toque em candles, confluência com pivô M15 fechado, horário do pivô M15 e eventual rompimento por fechamentos. As classificações são regras observáveis, não probabilidades:

- LOCAL_PIVOT: extremo confirmado no timeframe do perfil, sem os critérios extras.
- RETESTED_LOCAL: pelo menos `PlanObstacleMinTouches=2`, com separação `PlanObstacleTouchSeparation=2` e duração `PlanObstacleMinSpanBars=3`. O candle do pivô conta como primeiro toque; velas que apenas confirmaram o pivô não contam como reteste. Tolerância padrão1pip.
- M15_CONFLUENCE: existe pivô M15 confirmado, perto do nível do perfil dentro da tolerância; seu horário é registrado. Não significa que o nível foi obtido exclusivamente do M15 nem que vá segurar o preço.
- BROKEN_PIVOT_BASELINE: pivô atravessado por pelo menos dois fechamentos consecutivos além da tolerância depois de sua confirmação. Retido somente na política de comparação original.

Tudo usa candles fechados. Uma máxima/mínima intrabar ou um único tick não declara rompimento. A consulta M15 usa seus últimos candles fechados, nunca vela em formação. Toques/idade são medidos no timeframe do perfil (M5 ou M15), enquanto a confluência é sempre M15.

`PlanObstacleSelection`:

| Modo | Efeito |
|---|---|
| ALL_CONFIRMED_PIVOTS (padrão) | Seleciona o pivô mais próximo como antes e registra classificação. Nenhum pivô fraco é ignorado automaticamente. |
| RETESTED_OR_M15 | Experimento: aceita candidato retestado com duração mínima OU confluência M15; descarta rompidos por fechamentos. |
| M15_CONFIRMED_ONLY | Experimento: exige confluência M15 e ausência de rompimento confirmado. |

Sem candidato qualificado, rejeita; não trata ausência como espaço infinito. Sem dados M15, os modos experimentais rejeitam com motivo específico. O padrão pode continuar com obstáculos do perfil e registra M15 indisponível. Ignorar pivôs locais pode deixar atravessar níveis que ainda afetariam a execução: testar separadamente em backtest, sem assumir que M15 é sempre melhor. Nenhuma regra escolhe retrospectivamente o timeframe vencedor.

## Reavaliação: novas verificações do plano, não reenvios de ordens

`PlanEnableSpaceRecheck=false` por padrão; recurso opcional somente em TECHNICAL_PLAN. Quando explicitamente habilitado, uma recusa por alvo do lado errado/falta de espaço ou R:R líquido insuficiente pode guardar o sinal em memória para verificação posterior.

Padrões candidatos:

```text
PlanRecheckIntervalSeconds = 10
PlanRecheckLifetimeSeconds = 60
PlanRecheckMaxAttempts = 3
```

São no máximo três verificações adicionais, normalmente aos10/20/30 segundos, limitadas à validade e ao MESMO candle M5. O temporizador é de2s: os prazos são elegibilidade, não garantia de execução pontual. Não usa Sleep nem loop esperando o mercado.

A cada verificação: recalcula o sinal fechado original, direção, estratégia, sessão/notícias, cotação fresca, invalidação, obstáculo/classificação, ATR, buffer, SL, TP, lote, custos, margem e todos os limites. O plano é recalculado novamente antes do envio. Cancelamentos:

- Mudança de conta/servidor/tipo, reinício do EA ou alteração de inputs.
- Desarme/reativação de sessão, pausa, emergência, desconexão, perda de lease ou falha do diário.
- Novo candle M5, prazo atingido, número máximo, sinal/filtros invalidados ou preço atingindo o SL de invalidação ORIGINAL.
- Qualquer outro impedimento (margem, estrutura ausente, stop máximo, exposição, permissões, etc.) em vez de insistir.
- Qualquer tentativa de envio à corretora, mesmo rejeitada ou ambígua.

Esperar não cria espaço: o preço pode piorar, a tese pode vencer, e a operação deve continuar recusada. Em segundos dentro do mesmo candle, os pivôs fechados normalmente não mudam; as principais mudanças são cotação/spread e condições operacionais. Um novo pivô só passa a valer quando estiver confirmado, em análise futura de novos candles.

Pendências não são restauradas após reinício. A identidade e geração da autorização são fixadas no agendamento; desarmar e rearmar não herda pendência anterior. Antes do envio, a pendência é cancelada e uma marca persistente por conta/símbolo/candle impede duplicação após restart. Retcode de rejeição não libera reenvio automático. O próximo candle pode gerar NOVO sinal, segundo as regras normais; não há perseguição ilimitada da oportunidade original. A marca também protege o planejador anterior contra repetição do mesmo candle; não altera seus critérios de sinal/SL/TP.

As reavaliações não criam novos FSSignal nem repetem o alerta de novo sinal. Registram `recheck_scheduled`, `recheck_attempt`, `recheck_cancel`, `obstacle_review`, avaliações e rejeições normais no histórico. Toda nova ordem continua dependendo de ATIVAR DEMO/REAL, AutoTrade e permissões. Não foram removidos filtros para fazê-la acontecer.

## Instalação e configuração de teste

Mesmo branch development/safe-multistrategy, v2.13, EA + nove includes = dez arquivos de fonte verificados. Desligar Algo Trading, aguardar ficar flat, atualizar checkout, executar instalador, compilar F7. O script de teste de políticas pode ser copiado separadamente para MQL5/Scripts; não envia ordens.

Primeiro comparar o padrão com reavaliação desligada. No testador, testar:

1. EntryPlanner=TECHNICAL_PLAN, PlanObstacleSelection=ALL_CONFIRMED_PIVOTS, PlanEnableSpaceRecheck=true. Isola o efeito da reavaliação.
2. Depois testar RETESTED_OR_M15 e M15_CONFIRMED_ONLY separadamente, com a mesma configuração de reavaliação/custos/datas.
3. Inspecionar toques/span/horário M15 e candidatos descartados; confirmar que não há leitura futura, entradas após vencimento ou duplicadas após retcode/restart.
4. Demo apenas após compilação e testes: reativação consciente, observar pendências e execução; manter limites anteriores. Não operar REAL nesta tarefa.

Não alterar simultaneamente extensão de TP, horário, multiplicadores e política de obstáculos para depois atribuir resultado a um único ajuste. Rollback por inputs: PlanEnableSpaceRecheck=false e ALL_CONFIRMED_PIVOTS. Reinicializar cancela pendências. Gestão das posições já abertas mantém suas políticas persistidas. Rollback de código somente flat para f818424, pacote v2.12, com histórico e estados preservados.

## Evidência e limites dos testes

Testes locais: dois harnesses C++ compilam as próprias funções MQL compartilhadas. Novos casos cobrem toques separados e duração, ausência de rompimento por wick, rompimento por dois fechamentos, confluência M15, políticas de seleção e decisões de reavaliação (espera, momento elegível, prazo, máximo, conta/sessão/permissões/candle/sinal e dispatch). Doze testes Python cobrem instalação de conjunto completo e regressões de relatório/histórico.

Compilação completa MQL5, temporizadores reais, chamadas ao calendário, bloqueio persistente no terminal, seleção de posições/ordens, recuperação, desempenho e execução demo NÃO foram executados neste Linux. Script MQL5 ampliado mas não executado. Não se declara que essas mudanças foram operacionalmente aprovadas nem que melhoram rentabilidade. Nenhuma ordem real ou demo foi enviada nesta tarefa.
