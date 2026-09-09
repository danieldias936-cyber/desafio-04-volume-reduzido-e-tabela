# ============================================================================
# main.R — Desafio 04: Volume Reduzido de Toras e Tabela de Volume
# Talhão 8 — roda do início ao fim sem intervenção manual.
# ============================================================================

options(stringsAsFactors = FALSE)
set.seed(42)

dir.create("outputs", showWarnings = FALSE)
dir.create("outputs/figuras", showWarnings = FALSE)

source("scripts/00_funcoes_comuns.R")
source("scripts/01_relacao_hipsometrica.R")
source("scripts/02_cubagem_smalian.R")
source("scripts/03_parteA_volume_reduzido.R")
source("scripts/04_parteB_tabela_volume.R")

# ----------------------------------------------------------------------------
# Leitura dos dados (convertidos para CSV a partir dos .xlsx originais)
# ----------------------------------------------------------------------------
cubagem    <- read.csv("data/cubagem.csv", encoding = "UTF-8", check.names = TRUE)
inventario <- read.csv("data/inventario.csv", encoding = "UTF-8", check.names = TRUE)

names(cubagem)[1] <- "Talhao"
# Renomeia por posição (robusto a problemas de acentuação/encoding no cabeçalho):
# FILIAL, IDADE, REGIME, ESPACAMENTO, CLONE, MES_PLANTIO, AI, TALHAO, SITIO,
# PARCELA, FILEIRA, ARVORE, DAP, HT
names(inventario) <- c("FILIAL", "IDADE", "REGIME", "ESPACAMENTO", "CLONE",
                        "MES_PLANTIO", "AI", "TALHAO", "SITIO", "PARCELA",
                        "FILEIRA", "ARVORE", "DAP", "HT")

cat("== Dados carregados ==\n")
cat("Cubagem: ", nrow(cubagem), " registros / ", length(unique(cubagem$Arv)), " árvores\n", sep = "")
cat("Inventário: ", nrow(inventario), " árvores\n\n", sep = "")

# ============================================================================
# DESAFIO 03 (reaproveitado): volume real (Smalian) das 36 árvores cubadas
# ============================================================================
volumes_smalian <- calcular_volumes_smalian(cubagem)
cat("== Volume real (Smalian) — resumo ==\n")
print(summary(volumes_smalian$volume_real_m3))
cat("\n")

# ============================================================================
# DESAFIO 02 (reaproveitado): relação hipsométrica ajustada na subamostra
# do inventário (fileiras 3, 4 e 5)
# ============================================================================
hip <- ajustar_relacao_hipsometrica(inventario)
cat("== Relação hipsométrica — comparação de modelos (R^2) ==\n")
print(hip$tabela_comparacao)
cat("Modelo escolhido:", hip$melhor_modelo, "\n\n")

# ============================================================================
# PARTE A — Volume reduzido de toras (Francon/Hoppus) x geométrico (Huber)
#           x real (Smalian)
# ============================================================================
cat("== PARTE A: segmentação em toras e volumes ==\n")
parteA <- calcular_parteA(cubagem, volumes_smalian)

write.csv(parteA, "outputs/volume_reduzido_toras.csv", row.names = FALSE)

cat("Árvores processadas na Parte A:", sum(!is.na(parteA$volume_geometrico_m3)), "de", nrow(parteA), "\n")
cat("Razão média Francon/Geométrico:", round(mean(parteA$razao_francon_geometrico, na.rm = TRUE), 4),
    " (teórica = ", round(pi / 4, 4), ")\n", sep = "")
cat("Razão média Francon/Real (Smalian):", round(mean(parteA$razao_francon_real, na.rm = TRUE), 4), "\n")
cat("Volume total real (36 árvores):", round(sum(parteA$volume_real_m3), 3), "m3\n")
cat("Volume total geométrico (Huber):", round(sum(parteA$volume_geometrico_m3, na.rm = TRUE), 3), "m3\n")
cat("Volume total Francon (Hoppus):  ", round(sum(parteA$volume_francon_m3, na.rm = TRUE), 3), "m3\n\n")

# ============================================================================
# PARTE B — Equações de volume, RNA, tabela de volume, aplicação ao inventário
# ============================================================================
cat("== PARTE B: equações de volume ==\n")

eqs <- ajustar_equacoes_volume(volumes_smalian)

# --- Predições dentro da amostra (ajuste) -----------------------------------
pred_simples <- predizer_simples(eqs$simples, volumes_smalian$dap_cm)
pred_spurr   <- predizer_spurr(eqs$spurr, volumes_smalian$dap_cm, volumes_smalian$altura_m)
pred_sh      <- predizer_sh(eqs$sh, volumes_smalian$dap_cm, volumes_smalian$altura_m, eqs$fc_meyer)

met_simples <- metricas_ajuste(volumes_smalian$volume_real_m3, pred_simples)
met_spurr   <- metricas_ajuste(volumes_smalian$volume_real_m3, pred_spurr)
met_sh      <- metricas_ajuste(volumes_smalian$volume_real_m3, pred_sh)

# --- LOOCV para as equações de regressão ------------------------------------
loocv_simples <- loocv_lm(volume_real_m3 ~ I(dap_cm^2), volumes_smalian)
loocv_spurr   <- loocv_lm(volume_real_m3 ~ I(dap_cm^2 * altura_m), volumes_smalian)
loocv_sh_log  <- loocv_lm(log(volume_real_m3) ~ log(dap_cm) + log(altura_m), volumes_smalian)
loocv_sh      <- exp(loocv_sh_log) * eqs$fc_meyer

metL_simples <- metricas_ajuste(volumes_smalian$volume_real_m3, loocv_simples)
metL_spurr   <- metricas_ajuste(volumes_smalian$volume_real_m3, loocv_spurr)
metL_sh      <- metricas_ajuste(volumes_smalian$volume_real_m3, loocv_sh)

# --- Escolha da equação de dupla entrada (maior R^2 em LOOCV) ---------------
r2_dupla <- c(spurr = unname(metL_spurr["r2"]), schumacher_hall = unname(metL_sh["r2"]))
modelo_dupla_escolhido <- names(which.max(r2_dupla))
cat("Equação de dupla entrada escolhida (maior R^2 em LOOCV):", modelo_dupla_escolhido, "\n\n")

if (modelo_dupla_escolhido == "spurr") {
  predizer_dupla_geral <- function(dap, ht) predizer_spurr(eqs$spurr, dap, ht)
} else {
  predizer_dupla_geral <- function(dap, ht) predizer_sh(eqs$sh, dap, ht, eqs$fc_meyer)
}

# --- Tabela-resumo de coeficientes e métricas (equacoes_volume.csv) ---------
extrair_coefs <- function(modelo, nomes) {
  b <- coef(modelo)
  setNames(as.numeric(b[nomes]), nomes)
}

tab_equacoes <- data.frame(
  modelo = c("Simples entrada (V~DAP^2)",
             "Dupla entrada - Spurr (V~DAP^2*HT)",
             "Dupla entrada - Schumacher-Hall (lnV~lnDAP+lnHT)"),
  formula = c("V = b0 + b1*DAP^2",
              "V = b0 + b1*(DAP^2*HT)",
              "ln(V) = b0 + b1*ln(DAP) + b2*ln(HT); V=exp(pred)*FC_Meyer"),
  b0 = c(coef(eqs$simples)[1], coef(eqs$spurr)[1], coef(eqs$sh)[1]),
  b1 = c(coef(eqs$simples)[2], coef(eqs$spurr)[2], coef(eqs$sh)[2]),
  b2 = c(NA, NA, coef(eqs$sh)[3]),
  fator_correcao_meyer = c(NA, NA, eqs$fc_meyer),
  r2_ajuste   = c(met_simples["r2"],  met_spurr["r2"],  met_sh["r2"]),
  rmse_ajuste = c(met_simples["rmse"], met_spurr["rmse"], met_sh["rmse"]),
  r2_loocv    = c(metL_simples["r2"],  metL_spurr["r2"],  metL_sh["r2"]),
  rmse_loocv  = c(metL_simples["rmse"], metL_spurr["rmse"], metL_sh["rmse"])
)
rownames(tab_equacoes) <- NULL
write.csv(tab_equacoes, "outputs/equacoes_volume.csv", row.names = FALSE)
cat("== Equações de volume — métricas de ajuste e LOOCV ==\n")
print(tab_equacoes[, c("modelo", "r2_ajuste", "rmse_ajuste", "r2_loocv", "rmse_loocv")])
cat("\n")

# --- Gráficos de resíduos (diagnóstico) -------------------------------------
png("outputs/figuras/residuos_modelos.png", width = 1200, height = 450, res = 130)
par(mfrow = c(1, 3))
plot(volumes_smalian$volume_real_m3, volumes_smalian$volume_real_m3 - loocv_simples,
     xlab = "Volume real (m3)", ylab = "Resíduo LOOCV", main = "Simples entrada", pch = 19)
abline(h = 0, col = "red", lty = 2)
plot(volumes_smalian$volume_real_m3, volumes_smalian$volume_real_m3 - loocv_spurr,
     xlab = "Volume real (m3)", ylab = "Resíduo LOOCV", main = "Dupla entrada - Spurr", pch = 19)
abline(h = 0, col = "red", lty = 2)
plot(volumes_smalian$volume_real_m3, volumes_smalian$volume_real_m3 - loocv_sh,
     xlab = "Volume real (m3)", ylab = "Resíduo LOOCV", main = "Dupla entrada - Schumacher-Hall", pch = 19)
abline(h = 0, col = "red", lty = 2)
dev.off()

# --- Tabela de volume de dupla entrada (DAP x HT) ---------------------------
tabela_volume <- construir_tabela_volume(volumes_smalian, predizer_dupla_geral)
write.csv(tabela_volume, "outputs/tabela_volume.csv", row.names = FALSE)
cat("== Tabela de volume (dupla entrada,", modelo_dupla_escolhido, ") ==\n")
print(tabela_volume)
cat("\n")

# ============================================================================
# Aplicação das três abordagens ao inventário (215 árvores)
# ============================================================================
cat("== Aplicando as três abordagens ao inventário (215 árvores) ==\n")

inv <- data.frame(
  arvore   = inventario$ARVORE,
  dap_cm   = inventario$DAP,
  altura_medida_m = inventario$HT
)
inv$altura_faltante <- inv$altura_medida_m <= 0
inv$altura_m <- ifelse(inv$altura_faltante, hip$prever_altura(inv$dap_cm), inv$altura_medida_m)

inv$volume_simples_entrada_m3 <- predizer_simples(eqs$simples, inv$dap_cm)
inv$volume_dupla_entrada_m3   <- predizer_dupla_geral(inv$dap_cm, inv$altura_m)

# Volumes não podem ser negativos (possível em pequenas extrapolações lineares)
inv$volume_simples_entrada_m3 <- pmax(inv$volume_simples_entrada_m3, 0)
inv$volume_dupla_entrada_m3   <- pmax(inv$volume_dupla_entrada_m3, 0)

volume_povoamento <- data.frame(
  arvore = inv$arvore,
  dap_cm = round(inv$dap_cm, 3),
  altura_m = round(inv$altura_m, 3),
  altura_estimada = inv$altura_faltante,
  volume_simples_entrada_m3 = round(inv$volume_simples_entrada_m3, 5),
  volume_dupla_entrada_m3   = round(inv$volume_dupla_entrada_m3, 5)
)

total_simples <- sum(volume_povoamento$volume_simples_entrada_m3)
total_dupla   <- sum(volume_povoamento$volume_dupla_entrada_m3)

linha_total <- data.frame(
  arvore = "TOTAL_TALHAO", dap_cm = NA, altura_m = NA, altura_estimada = NA,
  volume_simples_entrada_m3 = round(total_simples, 3),
  volume_dupla_entrada_m3   = round(total_dupla, 3)
)
volume_povoamento_saida <- rbind(volume_povoamento, linha_total)
write.csv(volume_povoamento_saida, "outputs/volume_povoamento.csv", row.names = FALSE)

cat("Volume total do talhão 8 (215 árvores):\n")
cat("  Simples entrada: ", round(total_simples, 3), " m3\n", sep = "")
cat("  Dupla entrada (", modelo_dupla_escolhido, "): ", round(total_dupla, 3), " m3\n", sep = "")
cat("\nProcessamento concluído. Arquivos gravados em outputs/.\n")
