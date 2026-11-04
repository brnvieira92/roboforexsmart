# Forex Smart 3.00 — uma estratégia: ML + price action

A branch `development/safe-multistrategy` agora contém **uma única estratégia ativa**, `ML_PA_V1`, com **seis inputs**. Os módulos LEGACY, multistrategy, planner, TP monetário rígido e filas antigas foram retirados. O histórico Git preserva o rollback da v2.16 (`3d9b9b9`).

O sistema treina um classificador real com candles do seu MT5 e exige evidência fora da amostra. **Nenhum modelo lucrativo foi demonstrado ou embarcado nesta entrega.** Sem modelo qualificado, o painel mostra **SEM MODELO** e não envia ordens. Não é uma regra fixa disfarçada de machine learning.

## Atualizar e preparar no Windows

1. Desligue Algo Trading, retire o EA antigo do gráfico e faça a migração **sem posições antigas do robô abertas**. O novo EA recusa assumir posições de versões anteriores. Não exclua histórico, credenciais ou planos locais.
2. Na pasta clonada do projeto:

```powershell
git switch development/safe-multistrategy
git pull --ff-only origin development/safe-multistrategy
py tools\install_mt5.py "CAMINHO DA PASTA DE DADOS DO MT5"
```

O instalador aceita a conversão de finais de linha LF/CRLF do Windows, mantendo a verificação do conteúdo por hash. Alterações reais de código continuam sendo recusadas.

O instalador confere as **cinco fontes**, faz backup, retira os includes aposentados e guarda/remove o `.ex5` antigo para evitar executar a versão errada. Não compila. Abra `MQL5\Experts\ForexSmart.mq5` no MetaEditor, pressione **F7** e confira v3.00 e zero erros. Compilação completa MQL5 não foi executada no ambiente Linux desta entrega.

3. Deixe o MT5 aberto e conectado à sua **conta demo USD**, com histórico M15 dos quatro pares carregado. No PowerShell do projeto:

```powershell
py -m pip install -r requirements-ml-windows.txt
py tools\prepare_forex_ml.py
```

Esse comando lê candles fechados, exporta dados, treina, calibra e avalia o modelo. **Não envia ordens, não solicita credenciais e não ativa o EA.** Solicita até30000 velas por par, mínimo6000. Se faltar histórico, aumente o limite de barras do terminal/carregue os gráficos e repita. A disponibilidade depende da corretora.

O resultado fica em `artifacts\ForexSmart-ml-report.json`. Se Kelly bloquear o teste inteiro, o relatório separa esse bloqueio de desempenho negativo e inclui uma simulação diagnóstica sem Kelly, que não autoriza operar. Se houver qualificação, o modelo é copiado para `MQL5\Files\ForexSmart-ml-model.csv` da instalação de MT5 informada no console. Se os dados não sustentarem vantagem estimada, **nenhum modelo novo será instalado** e os motivos ficam no relatório. Isso é um resultado de pesquisa, não um erro a contornar mudando números do modelo.

Se houver mais de um MT5 instalado:

```powershell
py tools\prepare_forex_ml.py --terminal "C:\CAMINHO\terminal64.exe"
```

4. Anexe uma única instância do ForexSmart ao gráfico. Confira os seis inputs, selecione `AutoTrade=true` para execução, habilite as permissões/Algo Trading e clique **ATIVAR DEMO**. O botão **Carregar modelo** relê o arquivo e desarma a sessão; depois é necessária ativação manual. Não apague marca de duplicidade para forçar entrada.

## Os seis inputs

| Input | Padrão | Uso |
|---|---:|---|
| AutoTrade | false | Alertas/análise ou execução autorizada |
| RiskPercent | .25 | Teto de risco por operação sobre equity, limitado a1% |
| ProfitUSD | 5 | Objetivo **aproximado** para dimensionar lote, ajustável de3a10USD |
| DailyLossPercent | 2 | Bloqueio de novas entradas pela perda diária de equity |
| CommissionPerLotRoundTurn | 0 | Comissão USD por lote, ida+volta; precisa coincidir com o treino |
| TelegramNotifications | true | Usa o arquivo local de Telegram existente |

Não há mais seletores de estratégia, dezenas de filtros, horários, ADX, pivôs ou modo paciente. M15 e pares `EURUSD#, USDJPY#, GBPUSD#, USDCHF#` fazem parte da política única. Os padrões são candidatos, não evidência de rentabilidade.

## Como opera

Price action é descrito por13 características de candles fechados: corpo, pavios, deslocamentos, posição na faixa, espaço recente e spread/volatilidade. Um classificador logístico treinado estima o resultado de compra/venda. Entre os candidatos, prioriza maior probabilidade estimada, com no máximo duas posições totais e uma por par.

SL fica além dos extremos das últimas três velas fechadas mais buffer. TP tem1.25vezes a distância inicial do stop. O **lote**, não a distância do TP, busca o valor aproximado em USD. Arredondamento, lote mínimo, custos e execução podem gerar valor menor ou, no lote mínimo, até10USD estimados. Não há promessa de5USD exatos nem ganho garantido.

Após fechamento favorável de pelo menos1R, pode mover o stop para entrada+reserva de custos ou estrutura mais favorável, sem afrouxá-lo. Sem parciais. A posição tem prazo de oito velas M15. Regras de saída são as mesmas usadas para criar os rótulos do treinamento, com limitações explícitas de simulação.

Lote respeita risco até o stop, margem livre, Kelly fracionado, orçamento e volume mínimo/step. Permanecem autorizações, proteção contra duplicidade, margem, perda diária, integridade do plano e modelo, cotação válida e risco agregado. Posições manuais contam nos limites; posição sem SL pode bloquear novas entradas por risco desconhecido. Não existem bloqueios técnicos antigos por obstáculo/ADX/R:R2/teto20pips.

## Livro, dados e validação

[Especificação, adaptação do capítulo19, Kelly, treinamento e limitações](docs/ML_PRICE_ACTION.md).

Os itens19.1.3.1 e19.1.3.2 do livro tratam de **dimensionamento**, não de um sinal de compra/venda com ML. Kelly é `G − (1−G)/V`. O exemplo G70%, V3 resulta60%, embora o texto diga50%. O robô aplica apenas1/4de Kelly, ainda limitado pelo RiskPercent e teto1%; não arrisca50% ou60% da conta.

Testes:

```powershell
py -m unittest discover -s tests -v
```

Há comparação das funções matemáticas MQL com Python por harness C++ quando g++ está disponível. A integração MT5, MetaEditor, margem da corretora, fills, calendário e forward demo não foram executados neste Linux. Modelos/dados de testes são sintéticos e nunca são instalados. Dados reais atuais ainda precisam ser exportados do seu terminal para o primeiro treinamento.

## Telegram e histórico

Credenciais permanecem em `MQL5\Files\ForexSmart-telegram.txt` (token na primeira linha e chat_id na segunda). Permita `https://api.telegram.org` nas URLs de WebRequest do MT5. Não compartilhe esse arquivo. O Telegram informa entradas automáticas, entradas humanas e saídas com resultado; não recebe comandos remotos.

O CSV anterior é preservado. Novos eventos usam `ML_PA_V1`. Sempre abra **uma cópia** do histórico, para não bloquear sua gravação.

```powershell
py tools\ml_journal_report.py "CAMINHO DA COPIA DO HISTORICO.csv"
```

O painel mostra saldo/equity, sessão, modelo, risco, objetivo e posições. Pausar e emergência desarmam novas entradas; não liquidam toda a conta. A gestão das próprias posições ML continua quando houver permissão; SL/TP do servidor permanecem se o terminal estiver offline. Reconexão ou perda de permissão exige reativação manual.
