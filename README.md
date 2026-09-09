# Desafio 04 — Volume Reduzido de Toras e Tabela de Volume (Talhão 8)

Este repositório resolve o Desafio 04, que dá continuidade aos Desafios 01, 02
e 03 (hipsometria, relação hipsométrica e cubagem rigorosa/Smalian) usando as
mesmas bases: `cubagem.xlsx` (36 árvores) e `inventa_rio.xlsx` (215 árvores do
talhão 8).

A metodologia do Desafio 03 usada como base aqui (função de Smalian, função
de interpolação de diâmetro) reproduz exatamente as funções documentadas nos
relatórios `Desafio03_ParteA` e `Desafio03_ParteB` do grupo, e não uma
reimplementação livre.

> **Observação:** o item de Rede Neural Artificial (RNA), sugerido nos passos
> 4 e 5 da Parte B do enunciado, foi deliberadamente deixado de fora deste
> trabalho, a pedido do grupo. Toda a Parte B se baseia apenas nas equações de
> regressão de simples e dupla entrada.

## Como rodar

```r
# na raiz do projeto
source("main.R")
```

O script roda do início ao fim sem intervenção manual e grava os quatro
arquivos de saída em `outputs/` (mais um gráfico de diagnóstico em
`outputs/figuras/`).

Os `.xlsx` originais foram convertidos para CSV (`data/cubagem.csv` e
`data/inventario.csv`) apenas para eliminar a dependência do pacote `readxl`
(não disponível no ambiente de execução); nenhum dado foi alterado na
conversão. Pacotes usados: apenas `base` e `stats` (nenhum pacote externo).

## Estrutura

```
main.R                                  # orquestra tudo, ponta a ponta
scripts/00_funcoes_comuns.R             # área seccional, Smalian, interpolação de diâmetro, Huber/Francon
scripts/01_relacao_hipsometrica.R       # relação hipsométrica (ajustada na subamostra do inventário)
scripts/02_cubagem_smalian.R            # Desafio 03: volume real (Smalian) por árvore
scripts/03_parteA_volume_reduzido.R     # Parte A: segmentação em toras + Huber + Francon
scripts/04_parteB_tabela_volume.R       # Parte B: equações de volume, tabela de volume
data/                                   # cubagem.csv, inventario.csv
outputs/                                # os 4 arquivos de saída + figura de resíduos
```

## Parte A — Volume reduzido de toras

**Escolhas e justificativa**

- **Altura inicial de toreamento: 0,30 m.** Desconsidera o toco/base da
  árvore. A base possui medição exata de diâmetro em `hi = 0,30 m` em todas
  as 36 árvores, dispensando qualquer interpolação no ponto de partida da
  segmentação.
- **Comprimento padrão de tora: 2,00 m.** Comprimento comum para toras
  curtas de eucalipto (ex.: celulose, laminação).
- **Apenas toras COMPLETAS de 2,00 m são contabilizadas** — o trecho
  remanescente entre a última tora completa e o topo da árvore é descartado,
  por não constituir uma tora comercial inteira.
- O **diâmetro no meio de cada tora** é obtido pela função de interpolação
  linear do Desafio 03 (`interp_diametro` / `diametro_interpolado`), aplicada
  à altura do ponto médio de cada tora.
- **Volume real (Smalian) por árvore**: reproduz exatamente `vol_smalian()`
  do Desafio 03 — o trecho entre o solo (h = 0) e a primeira medição de campo
  (h = 0,10 m) é **descartado** do volume total (não estimado por cilindro ou
  qualquer outra suposição), porque não há diâmetro medido na base e
  estimá-lo exigiria extrapolação sem respaldo empírico; o viés dessa omissão
  é desprezível (< 0,5% do volume, já que 0,10 m é irrisório frente às
  alturas totais de 13,6–28,5 m).

**Nota sobre as fórmulas do enunciado.** As fórmulas apresentadas no PDF do
desafio (`V = pi/40000 * (D_meio/100)^2 * L` e `V = (C/40000)^2 * L`) fazem
uma dupla conversão de unidade (cm → m) e não fecham dimensionalmente. Usamos
a forma metricamente consistente e usual em Dendrometria — a mesma do
Desafio 03 (`area_seccional = (pi/4)*(d_cm/100)^2`, algebricamente idêntica a
`pi/40000 * d_cm^2`):

- Geométrico (Huber): `V = (pi/40000) * D_meio² * L`
- Francon (Hoppus): `V = (pi/4) * V_huber`

**Resultados (36 árvores cubadas):**

| Grandeza | Total | Média/árvore |
|---|---|---|
| Volume real (Smalian) | 8,230 m³ | 0,2286 m³ |
| Volume geométrico (Huber) | 7,971 m³ | 0,2214 m³ |
| Volume Francon (Hoppus) | 6,261 m³ | 0,1739 m³ |

- **Razão Francon/Geométrico = 0,7854 (π/4) em todas as 36 árvores, sem
  nenhum desvio.** Não é um resultado empírico a ser verificado nos dados —
  é consequência algébrica direta de as duas fórmulas usarem o mesmo
  diâmetro do meio da tora: como `C = π×D`, a razão `V_francon/V_huber` se
  simplifica para π/4 para qualquer diâmetro, independentemente dos dados
  observados.
- **Razão Francon/Real (Smalian) = 0,756 em média** (mín. 0,686, máx. 0,770)
  — sistematicamente abaixo de π/4, porque o volume real (Smalian) cobre o
  fuste inteiro da base (0,10 m) ao topo, enquanto o volume Francon computa
  apenas as toras comerciais completas a partir de 0,30 m, descartando tanto
  a base quanto o trecho final não aproveitado. Essa razão tende a ser mais
  baixa nas árvores menores do talhão, porque o trecho descartado no topo,
  semelhante em comprimento absoluto entre árvores, representa uma fração
  proporcionalmente maior do volume total nelas.

**Por que a cadeia produtiva usa o volume Francon:** é um método simples,
padronizado e mensurável em campo (basta medir circunferência e comprimento
da tora, sem instrumentos sofisticados), historicamente ligado ao rendimento
esperado do desdobro de toras redondas em peças de seção quadrada
(esquadrejamento). Por já "embutir" essa perda esperada, ele aproxima melhor
o volume de madeira efetivamente aproveitável (serrada) do que o volume
geométrico cheio da tora ou o volume real total da árvore, que
superestimariam o rendimento efetivo — por isso é adotado como referência
comercial e por órgãos de controle florestal.

## Parte B — Tabela de volume

- **Simples entrada:** `V = b0 + b1*DAP²` (ajustado por mínimos quadrados nas
  36 árvores cubadas).
- **Dupla entrada:** foram testados o modelo de **Spurr**
  (`V = b0 + b1*(DAP²*HT)`) e o de **Schumacher-Hall**
  (`ln(V) = b0 + b1*ln(DAP) + b2*ln(HT)`, com destransformação usando o fator
  de correção de Meyer, `exp(syx²/2)`, para remover o viés da volta à escala
  original). A escolha entre os dois é feita automaticamente no script
  (`main.R`) com base no maior R² em validação cruzada leave-one-out (LOOCV);
  no ajuste realizado, o modelo de **Spurr** teve o melhor desempenho em LOOCV
  e foi o escolhido para a tabela de volume e a aplicação ao inventário.
- **Validação:** as duas equações de dupla entrada (e a de simples entrada)
  foram avaliadas tanto pelo ajuste dentro da amostra quanto por **LOOCV**
  (refit do modelo a cada árvore removida, prevendo o volume dessa árvore de
  fora). As métricas (R², RMSE) de cada abordagem, dentro da amostra e em
  LOOCV, estão em `outputs/equacoes_volume.csv`; os gráficos de resíduos
  (LOOCV) das três equações estão em `outputs/figuras/residuos_modelos.png`.
- Como esperado, o R² em LOOCV cai ligeiramente em relação ao R² de ajuste
  dentro da amostra para todos os modelos, mas a ordem de desempenho se
  mantém: a equação de dupla entrada de Spurr teve o melhor ajuste e o melhor
  desempenho em LOOCV, seguida de perto pela Schumacher-Hall, e a de simples
  entrada (que ignora a altura) ficou um pouco atrás das duas.
- **Tabela de volume** (`outputs/tabela_volume.csv`): matriz de volume médio
  estimado por classe de DAP (2 em 2 cm) x classe de altura (2 em 2 m),
  cobrindo a amplitude observada nas 36 árvores cubadas, usando a equação de
  dupla entrada escolhida.

## Relação hipsométrica (base para completar alturas do inventário)

Testamos quatro modelos na subamostra do inventário com altura medida
(fileiras 3, 4 e 5, n = 109):

| Modelo | R² (escala original) |
|---|---|
| Linear: `HT = b0 + b1·DAP` | 0,852 |
| Trorey (quadrático): `HT = b0 + b1·DAP + b2·DAP²` | **0,917** |
| Curtis (log-recíproco): `ln(HT) = b0 + b1·(1/DAP)` | 0,902 |
| Log-log: `ln(HT) = b0 + b1·ln(DAP)` | 0,864 |

O modelo de **Trorey** teve o melhor ajuste dentro da amostra, mas foi
**descartado** para uso final: por ser uma parábola, decresce para valores de
DAP distantes do vértice (~21,6 cm). Como parte das árvores do inventário sem
altura medida tem DAP abaixo da faixa amostrada (inclusive uma árvore com DAP
de apenas 5,05 cm), o modelo de Trorey extrapolado geraria alturas
biologicamente implausíveis. Optamos pelo modelo de **Curtis**, com ajuste
ligeiramente inferior, porém monotonicamente crescente e mais robusto para
extrapolação além da faixa amostrada.

## Aplicação ao inventário e volume do talhão

As alturas faltantes das 215 árvores do inventário (106 sem HT medida) foram
completadas pelo modelo de Curtis. As duas equações de volume (simples e
dupla entrada) foram então aplicadas às 215 árvores, e os volumes somados
para estimar o volume total do talhão 8 (ver última linha, `TOTAL_TALHAO`, de
`outputs/volume_povoamento.csv`).

| Abordagem | Volume total do talhão 8 (215 árvores) |
|---|---|
| Simples entrada | 55,54 m³ |
| Dupla entrada (Spurr) | 58,02 m³ |

- As duas estimativas ficam relativamente próximas (diferença de ~4,5%), com
  a dupla entrada estimando um volume maior — coerente com o fato de a
  simples entrada ignorar completamente a altura, cuja relevância estatística
  já foi demonstrada nos ajustes acima.
- **A árvore de menor DAP do inventário (5,05 cm), abaixo do menor DAP
  cubado (5,64 cm), gerou volume negativo pela equação de simples entrada**
  — artefato conhecido de extrapolar um modelo quadrático em DAP abaixo da
  faixa de calibração. Esse valor foi truncado em zero (ver `volume_povoamento.csv`,
  árvore 29), e a ocorrência é reportada aqui como limitação de extrapolação
  do modelo.
- **O uso de alturas estimadas (em vez de medidas) introduz sim um risco de
  erro relevante**, especialmente para árvores de DAP fora da faixa amostrada
  para o ajuste hipsométrico — como demonstra o caso acima. Esse risco é
  mitigável por uma escolha criteriosa do modelo hipsométrico, priorizando
  robustez à extrapolação (Curtis em vez de Trorey), mas não é eliminado: a
  abordagem de dupla entrada combina o erro da equação de volume com o erro
  da relação hipsométrica (erro composto), enquanto a de simples entrada, por
  não depender de HT, fica imune a essa fonte extra de incerteza.

## Arquivos de saída

| Arquivo | Conteúdo |
|---|---|
| `outputs/volume_reduzido_toras.csv` | 1 linha/árvore cubada: volume real (Smalian), geométrico (Huber), Francon (Hoppus) e razões |
| `outputs/equacoes_volume.csv` | Coeficientes e métricas (R², RMSE, ajuste e LOOCV) das equações de simples e dupla entrada |
| `outputs/tabela_volume.csv` | Matriz de volume estimado por classe de DAP x classe de altura |
| `outputs/volume_povoamento.csv` | 1 linha/árvore do inventário: DAP, altura (medida ou estimada), volume por cada uma das 2 abordagens, e total do talhão na última linha |
