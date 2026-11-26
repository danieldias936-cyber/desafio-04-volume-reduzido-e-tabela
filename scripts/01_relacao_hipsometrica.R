# ============================================================================
# 01_relacao_hipsometrica.R
# Reproduz o resultado do Desafio 02: relação hipsométrica (altura em função
# do DAP), ajustada na subamostra do inventário com altura medida (fileiras
# 3, 4 e 5), usada para estimar a altura das demais árvores do talhão.
# ============================================================================

ajustar_relacao_hipsometrica <- function(inventario) {

  sub <- inventario[inventario$HT > 0, ]

  # Testamos três modelos hipsométricos clássicos e escolhemos o de maior R^2
  # (todos ajustados/comparados na escala original de HT via R^2 de predição)

  # 1) Linear simples: HT = b0 + b1*DAP
  m_linear <- lm(HT ~ DAP, data = sub)

  # 2) Trorey (quadrático): HT = b0 + b1*DAP + b2*DAP^2
  m_trorey <- lm(HT ~ DAP + I(DAP^2), data = sub)

  # 3) Curtis (log-recíproco): ln(HT) = b0 + b1*(1/DAP)
  m_curtis <- lm(log(HT) ~ I(1 / DAP), data = sub)

  # 4) Log-log (potência): ln(HT) = b0 + b1*ln(DAP)
  m_loglog <- lm(log(HT) ~ log(DAP), data = sub)

  pred_r2 <- function(modelo, log_scale) {
    pred <- predict(modelo, newdata = sub)
    if (log_scale) pred <- exp(pred)
    1 - sum((sub$HT - pred)^2) / sum((sub$HT - mean(sub$HT))^2)
  }

  r2_linear <- pred_r2(m_linear, FALSE)
  r2_trorey <- pred_r2(m_trorey, FALSE)
  r2_curtis <- pred_r2(m_curtis, TRUE)
  r2_loglog <- pred_r2(m_loglog, TRUE)

  tabela_r2 <- data.frame(
    modelo = c("linear (HT~DAP)", "trorey (HT~DAP+DAP^2)",
               "curtis (ln HT ~ 1/DAP)", "log-log (ln HT ~ ln DAP)"),
    r2     = c(r2_linear, r2_trorey, r2_curtis, r2_loglog)
  )

  # O modelo de Trorey tende a ter o melhor ajuste dentro da amostra, mas é
  # uma parábola: fora da faixa de DAP amostrada (sobretudo em valores baixos,
  # distantes do vértice), a curva pode DECRESCER, produzindo alturas
  # biologicamente implausíveis para árvores finas do inventário. Por isso,
  # ele é deliberadamente excluído da escolha final, mesmo quando tem o maior
  # R² — preferimos o modelo monotonicamente crescente de maior R² entre os
  # demais (Curtis ou log-log), mais robusto para extrapolação.
  candidatos <- tabela_r2[tabela_r2$modelo != "trorey (HT~DAP+DAP^2)", ]
  melhor <- candidatos$modelo[which.max(candidatos$r2)]

  modelos <- list(linear = m_linear, trorey = m_trorey, curtis = m_curtis, loglog = m_loglog)
  escolhido <- switch(melhor,
    "linear (HT~DAP)"          = list(modelo = m_linear, tipo = "linear"),
    "curtis (ln HT ~ 1/DAP)"   = list(modelo = m_curtis, tipo = "log"),
    "log-log (ln HT ~ ln DAP)" = list(modelo = m_loglog, tipo = "log")
  )

  function_prever <- function(dap) {
    nd <- data.frame(DAP = dap)
    pred <- predict(escolhido$modelo, newdata = nd)
    if (escolhido$tipo == "log") pred <- exp(pred)
    pred
  }

  list(
    tabela_comparacao = tabela_r2,
    melhor_modelo     = melhor,
    prever_altura     = function_prever
  )
}
