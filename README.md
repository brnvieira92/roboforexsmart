# smartTrade — Forex Smart

Primeira versão de Expert Advisor MQL5. **Não compilada nem validada em MT5 neste ambiente Linux. Não existe evidência de rentabilidade.** Inicia somente com alertas (`AutoTrade=false`).

## Instalação e execução

1. No MT5 desktop, abra Arquivo → Abrir pasta de dados e copie `mt5/ForexSmart.mq5` para `MQL5/Experts/`.
2. Abra no MetaEditor e compile (F7). Corrija e valide qualquer diagnóstico antes de usar.
3. No Strategy Tester, selecione ForexSmart, M5, ticks reais, conta demo e histórico de todos os pares. Inclua spread, comissões e slippage; use períodos fora da amostra. Para testar entradas, configure `AutoTrade=true` no testador.
4. Anexe **uma única instância** a um gráfico demo. Configure os nomes exatos dos símbolos da corretora, incluindo sufixos. Aguarde carregar o histórico de todos os pares. Para alertas push, configure MetaQuotes ID nas opções do terminal.
5. Negociação automática exige `AutoTrade=true`, permissão no EA e Algo Trading no terminal. O botão Pausar bloqueia novas entradas, mas mantém a gestão das posições do robô.

## Estratégia e risco

Pullback e retomada no fechamento do candle M5 com EMAs 9/21; ATR 14 mede volatilidade. Compra exige tendência de alta e retomada da EMA9; venda usa o inverso. Não utiliza candles futuros. Analisa a lista inteira a cada dois segundos, processando cada novo candle uma vez.

TP inicial adaptativo: ATR × (1 + 2 × força), limitado pelo mínimo/máximo de **pontos da corretora**, não dinheiro nem pips. Força = distância EMA9/21 dividida pelo ATR, limitada a 1. O alvo é escolhido na entrada e reavaliado pela volatilidade e força atuais, sempre dentro do intervalo em relação à entrada. Atualizações exigem diferença superior a 0,25 ATR e distância válida da cotação. Não há classificador separado de scalping e tendência.

SL inicial de 1,5 ATR, respeitando distância mínima da corretora. Após 1 ATR favorável, trailing de 1 ATR sem afrouxar o stop; após 1,5 ATR, tenta realizar metade uma única vez por identificador de posição. **Parciais apenas em contas hedging**, respeitando lote mínimo e step. Netting mantém trailing, sem parcial. Gaps, execução e custos podem produzir perdas mesmo após breakeven.

Risco padrão 0,25% da equity por operação, teto de duas posições em toda a conta (inclui manuais), uma posição por símbolo e bloqueio de novas entradas após queda de equity diária de 2%. Ordens pendentes e operações de outros terminais podem ultrapassar esse limite; use uma instância e uma conta dedicada. O limite diário não liquida posições. A referência diária é persistida no terminal e começa na primeira execução de cada dia do servidor, não reconstrói o saldo à meia-noite.

Horários usam o servidor MT5 e UTC, sem deslocamento brasileiro fixo; acompanha o horário informado pela corretora. Não há filtro de sessões nem calendário de notícias. O mercado segue disponibilidade de ticks e regras da corretora.

## Painel e histórico

Painel nativo preto, verde e branco com saldo/equity, posições, pares, horário, modo e último evento; botões Pausar/Retomar e Status. Eventos de execução distinguem magic do Forex Smart, entradas humanas (magic zero) e outros robôs. Não altera stops de posições humanas. Saídas e parciais mostram resultado líquido **do negócio**, não consolidado de toda a operação; comissão de entrada pode ser separada.

CSV persistido em `MQL5/Files/ForexSmart-history.csv` (no testador, diretório do agente). Alertas locais e push opcional para oportunidades e negócios. Sem Telegram/WhatsApp nesta versão. O histórico nativo do MT5 é a fonte para reconciliação; transações ocorridas com o EA desligado não são importadas para o CSV.

## Desenvolvimento na nuvem

Python 3.12, biblioteca padrão, sem dependências externas:

```sh
cd /workspace/roboforexsmart
python3 -m unittest discover -s tests -v
python3 tools/history_report.py /caminho/ForexSmart-history.csv
```

Testes exercitam somente o leitor de histórico. Compilação MQL5, backtest, execução de ordens, trailing, parcial, reinício e alertas push **pendentes no MT5**. Não execute ordens reais antes dessa validação.

Pares configurados conforme informado: EURUSD#, USDJPY#, GBPUSD#, USDCHF#. O livro ainda não foi fornecido; a estratégia não foi atribuída a essa referência.

## Critérios antes de negociar

Validar rejeições da corretora, tamanho de lote e risco em diferentes moedas de conta, reinício após parcial, limites com posições humanas, hedging/netting, mercado fechado, spreads altos e perda de conexão. Medir drawdown, expectativa após custos, profit factor e estabilidade fora da amostra. O painel conta negócios de saída positivos/negativos e soma o resultado líquido histórico do magic do EA; parciais contam separadamente. Curva de equity e dashboard web ficam para a próxima implementação após validar o executor.
