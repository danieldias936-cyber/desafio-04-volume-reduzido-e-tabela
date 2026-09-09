# ============================================================================
# 03_parteA_volume_reduzido.R
# Parte A do Desafio 04: volume reduzido de toras (Francon/Hoppus) x volume
# geométrico (Huber) x volume real (Smalian), por árvore cubada.
# ============================================================================

# Parâmetros escolhidos pelo grupo (documentados também no README):
#   - Altura inicial de toreamento: 0.30 m (desconsidera o toco/base) — a
#     base possui medição exata de diâmetro em hi = 0,30 m em todas as 36
#     árvores, dispensando qualquer interpolação no ponto de partida.
#   - Comprimento padrão de tora comercial: 2.00 m
#   - Apenas toras COMPLETAS de 2,00 m são contabilizadas; o trecho
#     remanescente entre a última tora completa e o topo da árvore é
#     descartado, por não constituir uma tora comercial inteira.
ALTURA_INICIAL   <- 0.30
COMPRIMENTO_TORA <- 2.00

# ----------------------------------------------------------------------------
# Segmenta o fuste de UMA árvore em toras de comprimento fixo
# Retorna um data.frame com uma linha por tora: h_ini, h_fim, L, h_meio, d_meio
# ----------------------------------------------------------------------------
segmentar_toras <- function(df_arvore, h_inicial = ALTURA_INICIAL,
                             comprimento = COMPRIMENTO_TORA) {

  ht <- max(df_arvore$hi)
  if (h_inicial + comprimento > ht) return(NULL)

  # Apenas cortes que resultam em toras INTEIRAS de "comprimento" m
  n_toras <- floor((ht - h_inicial) / comprimento)
  cortes  <- h_inicial + (0:n_toras) * comprimento

  h_ini <- cortes[-length(cortes)]
  h_fim <- cortes[-1]
  h_meio <- (h_ini + h_fim) / 2
  L <- h_fim - h_ini
  d_meio <- interp_diametro(df_arvore, h_meio)

  data.frame(h_ini = h_ini, h_fim = h_fim, L = L, h_meio = h_meio, d_meio = d_meio)
}

# ----------------------------------------------------------------------------
# Aplica a segmentação + volumes de tora a todas as árvores cubadas e agrega
# por árvore, comparando com o volume real (Smalian).
# ----------------------------------------------------------------------------
calcular_parteA <- function(cubagem, volumes_smalian) {
  arvores <- unique(cubagem$Arv)

  agregados <- lapply(arvores, function(a) {
    df_a <- cubagem[cubagem$Arv == a, ]
    toras <- segmentar_toras(df_a)

    if (is.null(toras)) {
      v_geo <- NA_real_
      v_fra <- NA_real_
    } else {
      toras$v_huber   <- volume_huber(toras$d_meio, toras$L)
      toras$v_francon <- volume_francon(toras$d_meio, toras$L)
      v_geo <- sum(toras$v_huber)
      v_fra <- sum(toras$v_francon)
    }

    data.frame(
      arvore = a,
      dap_cm = df_a$DAP[1],
      altura_m = df_a$HT[1],
      volume_geometrico_m3 = v_geo,
      volume_francon_m3    = v_fra
    )
  })

  agregados <- do.call(rbind, agregados)

  saida <- merge(volumes_smalian, agregados, by = c("arvore", "dap_cm", "altura_m"))
  saida$razao_francon_geometrico <- saida$volume_francon_m3 / saida$volume_geometrico_m3
  saida$razao_francon_real       <- saida$volume_francon_m3 / saida$volume_real_m3

  saida[order(saida$arvore), ]
}
