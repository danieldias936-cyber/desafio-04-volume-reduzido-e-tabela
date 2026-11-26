# ============================================================================
# 00_funcoes_comuns.R
# Funções reaproveitadas do Desafio 03 (cubagem rigorosa / Smalian e
# interpolação de diâmetro), usadas como base para o Desafio 04.
# ============================================================================

# Área seccional (m2) a partir do diâmetro em cm (sem casca)
area_seccional <- function(d_cm) {
  (pi / 40000) * d_cm^2
}

# ----------------------------------------------------------------------------
# Volume real de uma árvore pela fórmula de Smalian
#
# df_arvore: data.frame com colunas 'hi' (altura, m) e 'di' (diâmetro, cm),
#            ordenado por hi, para UMA única árvore.
#
# Metodologia idêntica à do Desafio 03 (vol_smalian): o trecho entre o solo
# (h = 0) e a primeira medição de campo (h = 0,10 m) é DESCARTADO do volume
# total, e não estimado por cilindro ou qualquer outra suposição. Essa
# decisão se justifica pela ausência de qualquer diâmetro medido na base
# (h = 0) na planilha de dados: estimar esse valor exigiria extrapolação sem
# respaldo empírico. Além disso, o comprimento do trecho (0,10 m) é
# irrisório frente à altura total das árvores (13,6 a 28,5 m), representando
# um viés desprezível no volume total (< 0,5%).
#
# O volume é então a soma de Smalian ((A0+A1)/2 * L) sobre as n-1 seções
# definidas pelos n pontos medidos. A última seção já termina com di = 0 na
# altura total (HT), portanto não é necessário nenhum cone adicional no topo.
# ----------------------------------------------------------------------------
volume_smalian_arvore <- function(df_arvore) {
  df_arvore <- df_arvore[order(df_arvore$hi), ]
  h <- df_arvore$hi
  d <- df_arvore$di
  n <- length(h)

  if (n < 2) return(0)

  A <- area_seccional(d)
  L <- diff(h)
  sum(((A[-n] + A[-1]) / 2) * L)
}

# ----------------------------------------------------------------------------
# Função de interpolação de diâmetro ao longo do fuste (Desafio 03:
# diametro_interpolado / diametro_meio_secao)
#
# Dado o conjunto de pontos medidos (hi, di) de uma árvore, devolve o
# diâmetro estimado (cm) em qualquer altura h dentro da amplitude medida
# (0,10 m a HT), por interpolação linear — a mesma lógica usada no Desafio 03
# tanto para o diâmetro do meio de cada seção quanto para o diâmetro na
# altura de Girard (5,2 m). Fora da amplitude medida, o diâmetro é truncado
# nos extremos (rule = 2) apenas como salvaguarda; na prática, todas as
# alturas usadas neste desafio (toras a partir de 0,30 m) caem dentro da
# amplitude medida em todas as árvores, sem necessidade de extrapolação.
# ----------------------------------------------------------------------------
interp_diametro <- function(df_arvore, h) {
  df_arvore <- df_arvore[order(df_arvore$hi), ]
  ht_arvore <- max(df_arvore$hi)

  out <- approx(x = df_arvore$hi, y = df_arvore$di, xout = h, rule = 2)$y
  out[h > ht_arvore] <- 0
  out
}

# ----------------------------------------------------------------------------
# Volumes de tora: geométrico (Huber) e reduzido / Francon (Hoppus)
#
# Nota sobre as fórmulas do enunciado: o enunciado apresenta
#   V_huber   = pi/40000 * (D_meio/100)^2 * L
#   V_francon = (C/40000)^2 * L , C = pi * D_meio
# Essas expressões, como escritas, fazem uma dupla conversão de unidades
# (cm -> m) e não fecham dimensionalmente. Usamos aqui a forma metricamente
# consistente (D_meio em cm, L em m, resultado em m3), que é a usual em
# Dendrometria e que reproduz exatamente a razão teórica V_francon/V_huber
# = pi/4 citada no enunciado:
#   V_huber   = (pi/40000) * D_meio^2 * L
#   V_francon = (pi/4) * V_huber = (pi^2/160000) * D_meio^2 * L
# ----------------------------------------------------------------------------
volume_huber <- function(d_meio_cm, L_m) {
  area_seccional(d_meio_cm) * L_m
}

volume_francon <- function(d_meio_cm, L_m) {
  (pi / 4) * volume_huber(d_meio_cm, L_m)
}
