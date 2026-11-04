# Especificação da única estratégia ativa — ML_PA_V1

## Origem e alcance

Livro fornecido: *Análise Técnica dos Mercados Financeiros*, Flavio Alexandre Caldas de Almeida Lemos. Itens19.1.3.1 e19.1.3.2, páginas693–694 do PDF. O primeiro limita lote pela perda até o stop e pelo capital disponível; o segundo apresenta Kelly. Esses itens não prescrevem entradas por ML. A política de price action, horizonte, características e modelo abaixo são implementação do projeto, ainda sem rentabilidade demonstrada.

Fórmula do livro: `f = G − (1−G)/V`, G como fração e V=ganho médio/perda média. Exemplo G=.70,V=3 → f=.60; há inconsistência aritmética com os50% escritos no exemplo. Não foi copiado o percentual do exemplo para execução. A recomendação textual de arriscar no máximo1% foi preservada como teto; padrão do projeto.25%.

O capital de risco nesta implementação é a equity da conta dedicada ao robô, não o patrimônio pessoal. A gestão de posições manuais e falta de SL afetam a estimativa de risco total.

## Sinal único

- Universo fixo: EURUSD#,USDJPY#,GBPUSD#,USDCHF#, conta USD. Um classificador compartilhado, sem menus de estratégias ou pesos manuais.
- M15, análise apenas após fechamento e32velas fechadas para dados de entrada. Nenhum indicador é calculado com candle futuro.
-13variáveis: corpo normalizado, pavio favorável/contrário, retornos1/3/7velas, desvio da média20, posição na faixa20, distâncias à máxima/mínima20, amplitude, spread/ATR e corpo da vela anterior. ATR é média dos14TrueRanges nessa política, explicitamente não o Wilder da versão anterior. Valores limitados a±10 para estabilidade, padronização ajustada só no bloco de treino.
- Calcula as duas direções, aplica regressão logística aprendida e calibração Platt. Piso fixado antes do teste em.55, Kelly conservador positivo e economia líquida positiva. Isso não converte uma estimativa em probabilidade verdadeira conhecida.
- Ordena candidatos por probabilidade estimada, respeitando máximo2posições na conta e1por símbolo. Não há inversão automática de sinais recusados, pontuação manual, EMA/ADX de bloqueio, horário fixo de entrada ou obstáculos que impeçam TP por proximidade.

## Geometria e saída que o modelo aprende

Invalidação da compra: menor mínima das últimas3velas fechadas menos buffer. Venda: maior máxima mais buffer e spread (candles Bid convertidos para Ask). Buffer=max(.1ATR,spread). SL arredonda para fora pela grade do símbolo. Não é necessário esperar um pivô de duas velas futuras para confirmar o stop; o contexto é aprendido nas variáveis.

TP=1.25vezes o risco inicial de preço, arredondado para fora. ProfitUSD3–10 é um objetivo para o **lote**. Não modifica o alvo para atravessar estruturas ou buscar um dinheiro exato. Após arredondar lote para baixo, o ganho estimado pode ficar abaixo de3USD; se apenas o lote mínimo couber e seu ganho for até10USD, ele pode superar o objetivo5USD. Sempre respeita o orçamento de risco.

Stop móvel só é avaliado com fechamento de nova vela M15, depois de ganho fechado de pelo menos1R inicial. Compra propõe o maior entre entrada+reserva de custos e mínima da última vela−buffer; venda usa o inverso com Ask. Só melhora o SL atual e respeita distância da corretora/preço. Sem parcial. Saída por TP, SL/trailing ou fim de oito velas M15. Gap e latência podem exceder limites nominais.

Plano persistido antes do envio e por posição: símbolo, intenção, modelo, lado, candle inicial, entrada, SL/TP, R inicial, buffer, reserva de custos em preço, lote, orçamento, risco estimado e ordem. Nunca reconstrói R inicial a partir de um stop já movido. Arquivo ausente/corrompido ou propriedade netting mista desarma novas entradas. Instalação3.00 não assume a gestão das posições antigas2.x.

## Lote máximo e Kelly

Perda por lote=OrderCalcProfit até SL em valor absoluto + comissão round-turn + reserva monetária de4pontos (2na entrada,2na saída). Ganho por lote=OrderCalcProfit até TP−as mesmas reservas. Spread já está nos preços executáveis. Variação cambial de USDJPY/USDCHF é resolvida pelo terminal ao calcular dinheiro.

A fração usada é:

```text
p_risco = mínimo(probabilidade calibrada atual, G conservador observado)
f_Kelly = p_risco − (1−p_risco)/V conservador
fração = máximo(0, mínimo(RiskPercent/100, 1% , f_Kelly/4))
orçamento = equity × fração
lote = floor_step(mínimo(orçamento/perda_por_lote, ProfitUSD/ganho_por_lote))
```

Em seguida confere lote mínimo/máximo, ganho líquido positivo, custos/expectativa, margem livre com reserva10%, risco agregado (até mínimo de2×RiskPercent e1%da equity) e posições/ordens totais. Se houver posição manual sem SL, não presume riscozero. Não abre ordem para ajustar risco depois de resposta incerta; marca persistente impede repetir a intenção por símbolo/candle, mesmo se reiniciar.

Kelly usa uma estimativa empírica prudente: limite inferior Wilson95% para frequência de ganhos e90%da razão média ganho/perda da calibração. Esse fator90%é uma redução heurística, não intervalo estatístico de confiança do payoff. O payoff é fixado antes de avaliar o bloco final e precisa ser sustentado também pelo teste e stress. O G pode ser reduzido pelo teste; só é aprovado se continuar com Kelly positivo. Não se usa o resultado de uma única operação nem uma probabilidade escolhida pelo desenvolvedor. Com ganhos/perdas variáveis e dependência serial, o uso de G/V médios é uma aproximação inspirada no livro, não solução exata do ótimo logarítmico da distribuição completa.

Após fill, confere SL/TP, desvio, volume e risco. Violação desarma e provoca uma tentativa de fechar apenas a posição própria afetada. Não é garantia de risco máximo diante de gaps/falhas. Nunca afrouxa SL para salvar um plano.

## Exportação e treinamento

`prepare_forex_ml.py` usa a biblioteca MetaTrader5 no Windows apenas para inicializar conexão de leitura, consultar conta/especificações e obter barras fechadas. Não contém order_send ou login/senha. Mostra terminal/pasta usados, permite --terminal se houver múltiplos terminais. Dados ficam localmente em data/, fora do Git. MetaTrader5 pode abrir o último terminal usado; confira o caminho impresso antes de usar o modelo.

Solicita30000M15 por par; precisa de pelo menos6000em cada. Exporta OHLC, timestamp de servidor/API, spread, point, tick_size e contract_size. Precisam representar o mesmo broker/contrato usado no EA. Não há histórico completo suficiente nos CSV de sinais anexados ao chat; os snapshots são pequenos, sobrepostos e não substituem dados de treinamento.

Treino real: regressão logística regularizada, otimizada por gradiente com NumPy. Ajusta médias/desvios somente no treino, até50000amostras de fit por espaçamento determinístico. Rótulos: resultado líquido positivo ou não sob a política descrita, com SL/TP/trailing/prazo e custos. Entradas usam próxima abertura, com spread conhecido da vela anterior como proxy de entrada, evitando usar o spread completo da vela futura como variável. Saídas usam spreads históricos aproximados. Dados de OHLC são insuficientes para reconstruir cada tick/fill.

Divisão global por timestamp60/20/20, preservando simultaneidade dos quatro pares. Treino, calibração e teste separados cronologicamente, com purga dos rótulos que cruzam fronteiras e intervalo de oito velas antes das fronteiras. Sem split aleatório de janelas sobrepostas. Calibração Platt no segundo bloco; teste no bloco final sem reajustar pesos. G/V da calibração definem elegibilidade Kelly antes do teste. A redução posterior de G continua positiva e não amplia o conjunto de sinais elegíveis.

No teste escolhe direção pela probabilidade, nunca pelo ganho futuro. Simula carteira de no máximo2posições,1por par e ocupação até o fechamento da vela do evento. Se SL e TP forem tocados na mesma vela, SL primeiro; gap no SL usa abertura pior. Trailing só começa a valer na vela seguinte, sem supor percurso intrabar. Mede netR, PF, drawdown de resultados fechados, duração, Brier/log loss e desempenho por par; repete com spread1.5vezes.

Qualificação exige no mínimo100trades na calibração e no teste/stress, PF>=1.05, netRpositivo, evidência por par (20trades e resultado positivo), e Kelly conservador positivo. Esses limites são candidatos de engenharia fixados, não prova matemática de vantagem. Qualificação usa o holdout como decisão de seleção; ainda é necessário forward independente e controle da quantidade de hipóteses tentadas. Não repetir ajustes nesse mesmo holdout até obter lucro.

Se não qualificar, nenhum modelo novo é escrito no terminal. O relatório detalha a falha. Um modelo anterior válido não é apagado automaticamente pelo script; o EA não troca modelo enquanto opera sem ação manual. Carregar modelo desarma; é preciso autorizar novamente.

Artefato versionado/política/13características, checksumSHA256, custos e símbolos compatíveis. Validade90dias, avaliação deve terminar antes do tempo de execução; não pode usar modelo treinado no futuro do backtest. O checksum detecta corrupção acidental, não é certificado de origem nem garantia de performance. Arquivos treinados não são versionados no Git.

## Limitações materiais

- Nenhum modelo real aprovado foi produzido nesta tarefa: faltam candles do terminal do usuário. O EA não inventa um modelo para começar a operar.
- Sem MetaEditor/MT5 no Linux: compilação MQL5, API de corretora, fills, recuperação no terminal, forward e ordens reais/demo não foram executados.
- Simulação OHLC com spread estimado e stop-first; não é tick-exact. Stops mínimos históricos, margem/leverage, lote mínimo, dimensionamentoUSD, swaps e equity flutuante não são simulados na carteira de validação. Não use seus R normalizados como prova do resultado em dinheiro de uma conta específica.
- G/V e probabilidades são estimativas, sujeitas a erro, seleção, dependência serial, mudança de regime/broker e overfitting. Reduzir Kelly não cria vantagem inexistente.
- Custos de swap futuros não são estimados: o prazo2h pode cruzar rollover. Resultados podem ser menores ou negativos mesmo com objetivo pequeno.
- Stop móvel depende do terminal conectado/permissões; SL/TP do servidor continuam existindo se offline. Limite diário é ancorado na primeira equity observada no dia, persistida por conta; não reconstrói equity exata da meia-noite nem ajusta automaticamente cashflows extraordinários.
- Modelos de outra corretora, dados incompletos e reotimização frequente no mesmo teste invalidam as conclusões. Não há garantia de lucro3/5/10USD nem de frequência de operações.

## Migração e rollback

Todas as estratégias2.x foram removidas do EA ativo, assim como seus seletores e configurações. O novo instalador salva os fontes, módulos aposentados e ex5no backup, retira apenas os arquivos nomeados do projeto e o executável antigo. Credenciais, históricos, FSPlan e posições não são apagados ou liquidados. Remova a instância antiga do gráfico e migre somente sem posições antigas do robô. Arquivos de modelo e plano ausentes impedem atuação automática, explicitamente no painel.

Rollback exato somente sem posições novas abertas: checkout3d9b9b9, reinstalar pacote2.16 completo e recompilar. Preserve os backups e arquivos locais; não misture include de versões. Não faça merge automático na main.

Os documentos anteriores em docs/ são históricos e não descrevem parâmetros da3.00. README e este documento são as instruções atuais.


## Verificação desta entrega

31 testes automatizados passaram no ambiente local, incluindo a compilação C++ do próprio cabeçalho matemático MQL e comparação das13características/probabilidade com Python. Foram testados Kelly, arredondamento do lote, ausência de dados, split temporal com purga, stop-first, trailing sem usar o percurso futuro da vela, seleção sem olhar lucro futuro, máximo2posições, integridade do artefato, seis inputs, histórico e backup/aposentadoria dos módulos antigos.

O fluxo de treinamento também foi executado em uma fixture sintética de24000velas (6000por par), em /tmp, sem instalar nada. O modelo sem evidência foi recusado e o relatório gerado. Isso verifica o caminho de execução/recusa; não é resultado de Forex nem evidência de vantagem. Nenhum peso de fixture foi embarcado.

Compilação do EA completo no MetaEditor e treinamento/forward com dados reais do terminal continuam pendentes por indisponibilidade dessas ferramentas/dados nesta nuvem. A primeira etapa operacional é exportar e treinar no Windows conforme README, não habilitar entradas sem modelo.
