## Desafio 04 - Parte B, itens 4 e 5: Rede Neural Artificial (RNA)
## Estimativa de volume a partir de DAP e HT - Talhao 8
## Base de treino: 36 arvores cubadas (cubagem.xlsx)
## Aplicacao: 215 arvores do inventario (inventario.xlsx)

library(readxl)
library(dplyr)
library(ggplot2)
library(nnet)

set.seed(42)

# ------------------------------------------------------------
# 1. Base de calibracao (DAP, HT, Volume real por Smalian)
# ------------------------------------------------------------
cub <- read_excel("cubagem.xlsx")
names(cub) <- c("talhao", "arv", "hi", "di", "dap", "ht")
cub <- cub %>% arrange(arv, hi)

volume_smalian <- function(d) {
  d <- d %>% arrange(hi)
  n <- nrow(d)
  areas <- (pi / 40000) * d$di^2
  vol <- 0
  for (i in 1:(n - 1)) {
    vol <- vol + ((areas[i] + areas[i + 1]) / 2) * (d$hi[i + 1] - d$hi[i])
  }
  vol
}

arvores <- unique(cub$arv)
base36 <- lapply(arvores, function(a) {
  d <- cub %>% filter(arv == a)
  data.frame(arvore = a, dap = unique(d$dap)[1], ht = unique(d$ht)[1],
             vol_real = volume_smalian(d))
}) %>% bind_rows()

n <- nrow(base36)
cat("Base de calibracao:", n, "arvores. DAP:",
    round(min(base36$dap), 2), "-", round(max(base36$dap), 2), "cm | HT:",
    round(min(base36$ht), 2), "-", round(max(base36$ht), 2), "m\n\n")

# ------------------------------------------------------------
# 2. Padronizacao (z-score) das variaveis de entrada
# ------------------------------------------------------------
dap_mean <- mean(base36$dap); dap_sd <- sd(base36$dap)
ht_mean  <- mean(base36$ht);  ht_sd  <- sd(base36$ht)

padroniza_dap <- function(x) (x - dap_mean) / dap_sd
padroniza_ht  <- function(x) (x - ht_mean) / ht_sd

base36$dap_z <- padroniza_dap(base36$dap)
base36$ht_z  <- padroniza_ht(base36$ht)

# ------------------------------------------------------------
# 3. Treino da RNA final
#    1 camada oculta, 3 neuronios, saida linear, decay = 0.01
# ------------------------------------------------------------
rna_final <- nnet(
  vol_real ~ dap_z + ht_z, data = base36,
  size = 3, linout = TRUE, decay = 0.01,
  maxit = 500, trace = FALSE
)

cat("Rede: 2 entradas -> 3 neuronios (camada oculta) -> 1 saida\n")
cat("Numero de pesos:", length(rna_final$wts), "\n\n")

preve_rna <- function(dap, ht) {
  nd <- data.frame(dap_z = padroniza_dap(dap), ht_z = padroniza_ht(ht))
  as.numeric(predict(rna_final, newdata = nd))
}

pred_treino <- preve_rna(base36$dap, base36$ht)
sqe_treino <- sum((base36$vol_real - pred_treino)^2)
sqtot <- sum((base36$vol_real - mean(base36$vol_real))^2)
r2_treino <- 1 - sqe_treino / sqtot
rmse_treino <- sqrt(mean((base36$vol_real - pred_treino)^2))

cat("R2 (dentro da amostra):", round(r2_treino, 4),
    " RMSE:", round(rmse_treino, 5), "m3\n\n")

# ------------------------------------------------------------
# 4. Validacao cruzada leave-one-out (LOOCV)
#    Padronizacao recalculada a cada iteracao apenas com o treino
# ------------------------------------------------------------
loo_pred <- numeric(n)

for (i in 1:n) {
  treino <- base36[-i, ]
  teste  <- base36[i, ]

  dm <- mean(treino$dap); ds <- sd(treino$dap)
  hm <- mean(treino$ht);  hs <- sd(treino$ht)
  treino$dap_z <- (treino$dap - dm) / ds
  treino$ht_z  <- (treino$ht - hm) / hs

  rna_i <- nnet(vol_real ~ dap_z + ht_z, data = treino,
                size = 3, linout = TRUE, decay = 0.01,
                maxit = 500, trace = FALSE)

  nd <- data.frame(dap_z = (teste$dap - dm) / ds, ht_z = (teste$ht - hm) / hs)
  loo_pred[i] <- as.numeric(predict(rna_i, newdata = nd))
}

resid_loo <- base36$vol_real - loo_pred
sqe_loo <- sum(resid_loo^2)
r2_loocv <- 1 - sqe_loo / sqtot
rmse_loocv <- sqrt(mean(resid_loo^2))
rmse_loocv_pct <- 100 * rmse_loocv / mean(base36$vol_real)

cat("R2 (LOOCV):", round(r2_loocv, 4), "\n")
cat("RMSE (LOOCV):", round(rmse_loocv, 5), "m3 (", round(rmse_loocv_pct, 2), "%)\n")
cat("Diferenca R2 treino - LOOCV:", round(r2_treino - r2_loocv, 4), "\n\n")

# ------------------------------------------------------------
# 5. Tabela de metricas e previsoes individuais (LOOCV)
# ------------------------------------------------------------
metricas_rna <- data.frame(
  modelo = "RNA (1 camada oculta, 3 neuronios, decay=0.01)",
  n_arvores_treino = n,
  R2_dentro_amostra = round(r2_treino, 4),
  RMSE_dentro_amostra_m3 = round(rmse_treino, 5),
  R2_LOOCV = round(r2_loocv, 4),
  RMSE_LOOCV_m3 = round(rmse_loocv, 5),
  RMSE_LOOCV_pct = round(rmse_loocv_pct, 2)
)
write.csv(metricas_rna, "rna_metricas.csv", row.names = FALSE)
print(metricas_rna)

previsoes_loocv <- data.frame(
  arvore = base36$arvore, dap_cm = base36$dap, ht_m = base36$ht,
  volume_real_m3 = base36$vol_real,
  volume_predito_loocv_m3 = round(loo_pred, 5),
  residuo_m3 = round(resid_loo, 5)
)
write.csv(previsoes_loocv, "rna_previsoes_loocv.csv", row.names = FALSE)

# ------------------------------------------------------------
# 6. Graficos
# ------------------------------------------------------------
p1 <- ggplot(previsoes_loocv, aes(x = volume_real_m3, y = volume_predito_loocv_m3)) +
  geom_point(size = 2.2, color = "#2166ac") +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "red") +
  labs(title = "RNA - Volume observado vs. predito (LOOCV)",
       subtitle = paste0("R2 = ", round(r2_loocv, 3), " | RMSE = ", round(rmse_loocv, 4), " m3"),
       x = "Volume real - Smalian (m3)", y = "Volume predito pela RNA (m3)") +
  theme_minimal()
ggsave("rna_observado_vs_predito.png", p1, width = 6.5, height = 5.5, dpi = 150)

p2 <- ggplot(previsoes_loocv, aes(x = volume_predito_loocv_m3, y = residuo_m3)) +
  geom_point(size = 2.2, color = "#d6604d") +
  geom_hline(yintercept = 0, linetype = "dashed") +
  labs(title = "RNA - Residuos (LOOCV) vs. valores preditos",
       x = "Volume predito (m3)", y = "Residuo (m3)") +
  theme_minimal()
ggsave("rna_residuos.png", p2, width = 6.5, height = 5.5, dpi = 150)

# ------------------------------------------------------------
# 7. Aplicacao ao inventario (215 arvores)
# ------------------------------------------------------------
altura_hipsometrica <- function(dap) {
  32.739 * (1 - exp(-0.2227 * dap))^5.333
}

inv <- read_excel("inventario.xlsx")
names(inv) <- c("filial","idade","regime","espacamento","clone","mes_plantio",
                 "ai","talhao","sitio","parcela","fileira","arvore","dap","ht")

inv$ht_medida <- inv$ht > 0
inv$ht_final <- ifelse(inv$ht_medida, inv$ht, altura_hipsometrica(inv$dap))
inv$volume_rna_m3 <- preve_rna(inv$dap, inv$ht_final)

volume_rna_povoamento <- inv %>%
  transmute(arvore, parcela, fileira, dap_cm = dap,
            altura_m = ht_final, altura_medida = ht_medida,
            volume_rna_m3 = round(volume_rna_m3, 5))

write.csv(volume_rna_povoamento, "volume_rna_povoamento.csv", row.names = FALSE)

# ------------------------------------------------------------
# 8. Volume total do talhao
# ------------------------------------------------------------
area_amostrada_ha <- 6 * 441 / 10000
area_talhao_ha <- 48.7

vol_total_amostra <- sum(volume_rna_povoamento$volume_rna_m3)
vol_m3_ha <- vol_total_amostra / area_amostrada_ha
vol_total_talhao <- vol_m3_ha * area_talhao_ha

cat("\nVolume total na amostra (215 arvores):", round(vol_total_amostra, 3), "m3\n")
cat("Volume por hectare:", round(vol_m3_ha, 2), "m3/ha\n")
cat("Volume total do talhao (48,7 ha):", round(vol_total_talhao, 1), "m3\n")

write.csv(
  data.frame(abordagem = "RNA",
             volume_total_amostra_m3 = round(vol_total_amostra, 3),
             volume_m3_ha = round(vol_m3_ha, 2),
             volume_total_talhao_m3 = round(vol_total_talhao, 1)),
  "rna_volume_total_talhao.csv", row.names = FALSE
)
