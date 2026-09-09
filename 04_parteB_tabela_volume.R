# ============================================================================
# 04_parteB_tabela_volume.R
# Parte B do Desafio 04: equações de volume (simples e dupla entrada),
# tabela de volume e aplicação das abordagens ao inventário do talhão 8.
# (O item de Rede Neural Artificial (RNA) proposto no enunciado foi
#  deliberadamente deixado de fora, a pedido do grupo.)
# ============================================================================

# ----------------------------------------------------------------------------
# 1) Ajuste das equações de volume (simples e dupla entrada)
# ----------------------------------------------------------------------------
ajustar_equacoes_volume <- function(dados_cubagem) {
  # dados_cubagem precisa ter: dap_cm, altura_m, volume_real_m3

  # Simples entrada: V = b0 + b1 * DAP^2
  m_simples <- lm(volume_real_m3 ~ I(dap_cm^2), data = dados_cubagem)

  # Dupla entrada - Spurr: V = b0 + b1 * (DAP^2 * HT)
  m_spurr <- lm(volume_real_m3 ~ I(dap_cm^2 * altura_m), data = dados_cubagem)

  # Dupla entrada - Schumacher-Hall: ln(V) = b0 + b1*ln(DAP) + b2*ln(HT)
  m_sh <- lm(log(volume_real_m3) ~ log(dap_cm) + log(altura_m), data = dados_cubagem)
  # Fator de correção de Meyer para a destransformação do logaritmo
  syx_log <- summary(m_sh)$sigma
  fc_meyer <- exp((syx_log^2) / 2)

  list(simples = m_simples, spurr = m_spurr, sh = m_sh, fc_meyer = fc_meyer)
}

predizer_simples <- function(modelo, dap) {
  predict(modelo, newdata = data.frame(dap_cm = dap))
}

predizer_spurr <- function(modelo, dap, ht) {
  predict(modelo, newdata = data.frame(dap_cm = dap, altura_m = ht))
}

predizer_sh <- function(modelo, dap, ht, fc_meyer) {
  pred_log <- predict(modelo, newdata = data.frame(dap_cm = dap, altura_m = ht))
  exp(pred_log) * fc_meyer
}

# ----------------------------------------------------------------------------
# 2) Métricas de ajuste (R2, erro padrão residual / RMSE) na escala original
#    do volume (m3), mesmo para o Schumacher-Hall (ajustado em log).
# ----------------------------------------------------------------------------
metricas_ajuste <- function(obs, pred) {
  res <- obs - pred
  r2 <- 1 - sum(res^2) / sum((obs - mean(obs))^2)
  rmse <- sqrt(mean(res^2))
  syx_pct <- 100 * rmse / mean(obs)
  c(r2 = r2, rmse = rmse, syx_pct = syx_pct)
}

# ----------------------------------------------------------------------------
# 3) Validação cruzada Leave-One-Out (LOOCV), genérica, para lm e nnet
# ----------------------------------------------------------------------------
loocv_lm <- function(formula, data, transform_pred = identity) {
  n <- nrow(data)
  pred <- numeric(n)
  for (i in seq_len(n)) {
    m <- lm(formula, data = data[-i, ])
    p <- predict(m, newdata = data[i, ])
    pred[i] <- transform_pred(p)
  }
  pred
}

# ----------------------------------------------------------------------------
# 4) Tabela de volume de dupla entrada (matriz DAP x HT)
# ----------------------------------------------------------------------------
construir_tabela_volume <- function(dados_cubagem, predizer_dupla,
                                     largura_classe_dap = 2, largura_classe_ht = 2) {

  dap_min <- floor(min(dados_cubagem$dap_cm) / largura_classe_dap) * largura_classe_dap
  dap_max <- ceiling(max(dados_cubagem$dap_cm) / largura_classe_dap) * largura_classe_dap
  ht_min  <- floor(min(dados_cubagem$altura_m) / largura_classe_ht) * largura_classe_ht
  ht_max  <- ceiling(max(dados_cubagem$altura_m) / largura_classe_ht) * largura_classe_ht

  classes_dap <- seq(dap_min, dap_max - largura_classe_dap, by = largura_classe_dap)
  classes_ht  <- seq(ht_min, ht_max - largura_classe_ht, by = largura_classe_ht)

  dap_mid <- classes_dap + largura_classe_dap / 2
  ht_mid  <- classes_ht + largura_classe_ht / 2

  tabela <- outer(dap_mid, ht_mid, function(d, h) predizer_dupla(d, h))
  tabela <- pmax(tabela, 0)

  rotulo_dap <- sprintf("%.0f-%.0f", classes_dap, classes_dap + largura_classe_dap)
  rotulo_ht  <- sprintf("%.0f-%.0f", classes_ht, classes_ht + largura_classe_ht)

  df <- as.data.frame(tabela)
  colnames(df) <- rotulo_ht
  df <- cbind(classe_dap_cm = rotulo_dap, df)
  df
}
