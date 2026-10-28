# smartTrade — Forex Smart

Primeira versão de Expert Advisor MQL5. **Não compilada nem validada em MT5 neste ambiente Linux. Não existe evidência de rentabilidade.** Inicia somente com alertas (`AutoTrade=false`).

## Instalação e execução

1. No MT5 desktop, abra Arquivo → Abrir pasta de dados e copie `mt5/ForexSmart.mq5` para `MQL5/Experts/` e a pasta `mt5/Include` para `MQL5/Experts/Include/` (preserve essa estrutura).
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

CSV persistido em `MQL5/Files/ForexSmart-history.csv` (no testador, diretório do agente). Alertas locais e push opcional para oportunidades e negócios. Telegram opcional conforme configuração abaixo; WhatsApp não integrado. O histórico nativo do MT5 é a fonte para reconciliação; transações ocorridas com o EA desligado não são importadas para o CSV.

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


## Telegram — instalação passo a passo (v1.10)

1. Atualize o checkout no PowerShell, dentro da sua pasta do projeto:
   ```powershell
   git pull origin main
   ```
2. No MT5: **Arquivo → Abrir Pasta de Dados**. Copie os arquivos do projeto para estes destinos:
   ```text
   mt5/ForexSmart.mq5                   → MQL5/Experts/ForexSmart.mq5
   mt5/Include/ForexSmartTelegram.mqh   → MQL5/Experts/Include/ForexSmartTelegram.mqh
   ```
   Abra ForexSmart.mq5 no MetaEditor e pressione F7. Esta versão ainda precisa ser compilada e validada no seu terminal.
3. No Telegram, abra o **@BotFather** oficial, envie `/newbot` e siga as instruções. Guarde o token em local privado. Abra a conversa com o bot criado e envie `/start` e uma mensagem de texto.
4. Obtenha o chat ID no navegador **somente no seu computador**, substituindo o marcador abaixo pelo token. Não compartilhe a URL nem capturas dela, pois contêm a credencial:
   ```text
   https://api.telegram.org/bot<SEU_TOKEN>/getUpdates
   ```
   Procure `result` → `message` → `chat` → `id`. Use o ID de `chat`, não o de `from`. Se `result` estiver vazio, envie outra mensagem ao bot e atualize. Para grupo, adicione o bot ao grupo, envie um comando dirigido ao bot e use o ID negativo do chat. Um bot já usado por outro sistema com webhook/polling pode exigir um bot dedicado; não remova webhooks de outro serviço.
5. Na Pasta de Dados do MT5, abra `MQL5/Files`. Crie **ForexSmart-telegram.txt**, UTF-8, com exatamente duas linhas:
   ```text
   TOKEN_DO_BOT
   CHAT_ID_NUMERICO
   ```
   Substitua pelos valores reais, sem aspas, rótulos ou espaços. Confirme que não virou `.txt.txt`. Não use a pasta do projeto para guardar essa credencial. O arquivo é texto local: proteja o acesso ao computador e backups. Nunca envie token em chat, logs ou GitHub. Se exposto, revogue-o no BotFather.
6. Em **Ferramentas → Opções → Expert Advisors**, marque **Permitir WebRequest para as URLs listadas** e adicione apenas:
   ```text
   https://api.telegram.org
   ```
7. No gráfico com a única instância do ForexSmart, pressione F7 e configure **TelegramNotifications=true**. Para testar apenas alertas, deixe **AutoTrade=false**. Confirme em OK. O EA enfileira uma mensagem de conexão, enviada no próximo ciclo. Clique em **Status** para outro teste. Isso não abre operações.
8. Abra **Ctrl+T → Experts**. Sucesso: `Telegram: notificação entregue.` Confira a mensagem no Telegram. Essa confirmação indica que a API aceitou o envio, não que a pessoa leu. Teste em conta demo; não é necessário habilitar operações automáticas para testar Telegram.

### Mensagens e comportamento

Oportunidades não significam execução: entradas podem ser bloqueadas por risco, spread, margem ou posição existente. Entradas e saídas incluem direção do negócio, volume, preço, moeda e número do negócio. Na saída, COMPRA/VENDA é o lado do negócio de fechamento, não necessariamente o lado da posição original. Resultado é líquido do negócio, não o consolidado da posição. Eventos humanos e de outros robôs também são identificados. Parciais geram o evento de gestão e o negócio correspondente. Um alerta de stop é enviado quando cruza a entrada, sem notificar cada pequeno deslocamento. Limite diário é avisado uma vez por dia/instância. Não há comandos pelo Telegram nem importação de operações ocorridas com EA desligado.

Fila em memória: até 100 mensagens, uma tentativa por ciclo elegível, intervalo mínimo de quatro segundos, até três tentativas por mensagem; mensagens com mais de cinco minutos são descartadas. Reiniciar o EA limpa a fila. Falhas ambíguas de rede podem gerar duplicidade se o Telegram recebeu a mensagem mas a resposta se perdeu. Sem garantia de entrega nem persistência offline.

O WebRequest é síncrono: timeout de 1 segundo, executado depois da gestão e análise. Pode atrasar brevemente o próximo ciclo; stops já aceitos pela corretora continuam no servidor. Não é transporte adequado para comandos de emergência. O Testador de Estratégia desativa o Telegram automaticamente; alertas reais exigem terminal conectado.

### Diagnóstico

- HTTP `401`/`404`: confira o token; `400`: confira chat ID e arquivo; `403`: inicie a conversa, desbloqueie o bot e confira permissões no grupo. Esses erros suspendem envios até corrigir e recarregar o EA.
- HTTP `429`: limite da API; o robô espera 60 segundos antes de tentar novamente.
- HTTP `-1`: confira código de erro MT5, autorização WebRequest, conexão e firewall. O código `4014` normalmente indica chamada não permitida. Não compartilhe token para diagnóstico.
- Painel “habilitado” significa credencial carregada; somente mensagem recebida confirma o teste de entrega.

### Testes MQL5 sem envio

Copie `mt5/Scripts/TestForexSmartTelegram.mq5` para `MQL5/Scripts/` e o include para `MQL5/Experts/Include/`. Compile e execute o script em um gráfico demo. Deve imprimir `Telegram unit tests: PASS`. Testa encoding UTF-8, limites/ordem da fila e expiração, sem chamar Telegram nem precisar de token. Esses testes MQL5 não foram executados no ambiente Linux; os testes Python validam somente o leitor CSV.

## Evolução v2.00 — branch de desenvolvimento

Esta branch adiciona autorização por sessão, isolamento por conta/servidor, controles de custos e risco e quatro estratégias experimentais. **Não foi compilada nem executada no MT5 neste ambiente.** Não substitui automaticamente a versão da main.

Leia [auditoria, testes e procedimentos completos](docs/VALIDATION.md) antes de instalar. O modo padrão é `LEGACY`; os critérios EMA9/21/ATR14 continuam, mas as novas proteções podem rejeitar entradas que a v1.10 aceitaria. O resultado do backtest antigo não é evidência de rentabilidade da v2.

Para instalar a v2, copie **todos os arquivos de `mt5/Include/`** para `MQL5/Experts/Include/`, além do EA. A autorização requer `AutoTrade=true`, permissões do terminal, comissão conferida (`CommissionEstimateConfirmed=true`) e clique no botão **ATIVAR DEMO/REAL**. A cada reinício/troca de conta é necessário ativar novamente. Telegram continua com o mesmo arquivo local e URL; não existem comandos remotos.

O histórico novo usa `ForexSmart-<login>.<fingerprint-servidor>-history.csv`. O antigo `ForexSmart-history.csv` é preservado. `tools/history_report.py` aceita os dois formatos e agrega os novos eventos de negócios por estratégia/par; não calcula win rate por posição com base em parciais.

Testes locais sem MT5:

```sh
python3 -m unittest discover -s tests -v
g++ -std=c++17 -Wall -Wextra -Werror tests/native/test_core.cpp -o /tmp/forexsmart-core-tests
/tmp/forexsmart-core-tests
```

Nenhum desses comandos envia ordens. C++ compila apenas as políticas matemáticas compartilhadas com o EA. Compilação completa, backtest, painel, APIs MT5, recuperação real do terminal e operação demo permanecem na matriz de validação pendente.
