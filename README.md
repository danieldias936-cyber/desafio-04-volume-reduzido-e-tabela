# Desafio 04 — Parte B, itens 4 e 5: Rede Neural Artificial (RNA)

Modelagem por Rede Neural Artificial para estimativa de volume individual
das árvores do talhão 8, a partir de DAP e HT.

## 1. Arquitetura

| Parâmetro | Valor | Justificativa |
|---|---|---|
| Entradas | DAP e HT, padronizados (z-score) | Evita que a variável de maior escala (HT, em metros) domine o treinamento sobre a de menor escala (DAP, em cm). |
| Camadas ocultas | 1 | Amostra de calibração reduzida (36 árvores) não sustenta arquiteturas profundas. |
| Neurônios na camada oculta | 3 | Rede final com 13 pesos para 36 observações, mantendo a razão parâmetros/observações baixa. |
| Função de ativação | Logística (padrão do pacote `nnet`) | — |
| Saída | Linear (`linout = TRUE`) | Problema de regressão contínua. |
| Regularização | `decay = 0,01` (weight decay, L2) | Penaliza pesos elevados, reduzindo o risco de sobreajuste. |
| Validação | Leave-one-out (LOOCV) | Com 36 observações, a separação de um conjunto de teste fixo reduziria demais os dados de treino; o LOOCV usa cada árvore como teste exatamente uma vez. |

A padronização (média e desvio-padrão de DAP e HT) é recalculada, em cada
iteração do LOOCV, apenas com as 35 árvores de treino daquela iteração —
nunca com a árvore de teste, para não haver vazamento de informação entre
treino e teste.

## 2. Resultados

| Métrica | Dentro da amostra (treino) | LOOCV |
|---|---:|---:|
| R² | 0,9821 | 0,9778 |
| RMSE (m³) | 0,01207 | 0,01342 |
| RMSE (%) | — | 5,87% |

A diferença entre R² de treino e R² de LOOCV é de 0,0042. Uma diferença
pequena entre desempenho dentro e fora da amostra indica ausência de
sobreajuste relevante na arquitetura adotada.

### Comparação com as equações de regressão (ajustadas em entrega separada)

| Modelo | R² (LOOCV) | RMSE (LOOCV) |
|---|---:|---:|
| Simples entrada (DAP²) | 0,978 | 5,79% |
| Spurr (DAP²×HT) | 0,987 | 4,43% |
| Schumacher-Hall | 0,985 | 4,89% |
| RNA | 0,978 | 5,87% |

A RNA obteve desempenho equivalente ao da equação de simples entrada e
inferior ao das equações de dupla entrada (Spurr e Schumacher-Hall). Com
apenas 36 árvores de calibração, um modelo que parte de uma forma funcional
predefinida e fisicamente coerente (V proporcional a DAP²×HT, no caso de
Spurr) tende a apresentar desempenho igual ou superior ao de uma rede
neural, que estima a relação sem essa restrição estrutural. A vantagem
relativa da RNA tende a aparecer em amostras de calibração maiores.

### Análise gráfica dos resíduos

- `rna_observado_vs_predito.png`: os pontos acompanham a reta 1:1 ao longo
  de toda a amplitude de volumes observados.
- `rna_residuos.png`: os resíduos se distribuem em torno de zero, sem
  tendência sistemática. Observa-se leve aumento da dispersão nos volumes
  mais altos.

## 3. Aplicação ao inventário e volume total do talhão

A RNA treinada com as 36 árvores cubadas foi aplicada às 215 árvores do
inventário. As alturas não medidas (106 árvores, fileiras periféricas)
foram completadas pela relação hipsométrica ajustada no Desafio 02:

```
HT = 32,739 · (1 − e^(−0,2227 · DAP))^5,333      (Chapman-Richards)
```

| Resultado | Valor |
|---|---:|
| Volume total estimado na amostra (215 árvores) | 55,91 m³ |
| Volume por hectare | 211,30 m³/ha |
| Volume total do talhão 8 (48,7 ha) | 10.290,5 m³ |

## 4. Arquivos

```
entrega_rna/
├── README.md
├── rna_volume.R                     # treino, validacao LOOCV e aplicacao ao inventario
├── rna_metricas.csv                 # R2 e RMSE (treino e LOOCV)
├── rna_previsoes_loocv.csv          # previsao LOOCV individual das 36 arvores cubadas
├── volume_rna_povoamento.csv        # volume estimado nas 215 arvores do inventario
├── rna_volume_total_talhao.csv      # volume total (amostra, m3/ha, talhao)
├── rna_observado_vs_predito.png
└── rna_residuos.png
```

## 5. Execução

Pré-requisitos (R ≥ 4.3): pacotes `readxl`, `dplyr`, `ggplot2`, `nnet`.

```r
install.packages(c("readxl", "dplyr", "ggplot2", "nnet"))
```

Colocar `cubagem.xlsx` e `inventario.xlsx` no mesmo diretório do script e
executar:

```bash
Rscript rna_volume.R
```

O script é executado do início ao fim sem intervenção manual.
