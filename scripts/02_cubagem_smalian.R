# ============================================================================
# 02_cubagem_smalian.R
# Reproduz o resultado do Desafio 03: volume real por árvore (Smalian) a
# partir das 36 árvores cubadas rigorosamente.
# ============================================================================

calcular_volumes_smalian <- function(cubagem) {
  arvores <- unique(cubagem$Arv)

  resultado <- lapply(arvores, function(a) {
    df_a <- cubagem[cubagem$Arv == a, ]
    v <- volume_smalian_arvore(df_a)
    data.frame(
      arvore      = a,
      dap_cm      = df_a$DAP[1],
      altura_m    = df_a$HT[1],
      volume_real_m3 = v
    )
  })

  do.call(rbind, resultado)
}
