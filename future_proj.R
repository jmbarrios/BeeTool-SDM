library(terra)

library(readr)
library(dplyr)
library(magrittr)

# Load config
config <- config::get()

sdm_info_data <- "./entrega/sdm_models_info.csv" %>%
  read_csv()

future_conditions <- config %$%
  future_projection_config %$%
  rasters %>%
  purrr::map(rast)

aoi <- config %$%
  future_projection_config %$%
  aoi %>%
  vect

future_conditions <- future_conditions %>%
  purrr::map(crop, aoi)

# Binary models processing ----
BASEPATH <- fs::as_fs_path("./entrega/")
RESULT_CSV <- "enmeval_results.csv"
MODEL_FILE <- "Maxent_models.Rds"

binary_sp_smd <- sdm_info_data %>%
  filter(is_binary) %>%
  pull(spCode) %>%
  unique()
result_path <- fs::path(BASEPATH, binary_sp_smd)

enm_result <- fs::path(result_path[1], RESULT_CSV) %>%
  read_csv()
enm_model <- fs::path(result_path[1], MODEL_FILE)

model_bestAICc <- enm_result %>%
  filter(delta.AICc == 0) %>%
  pull(tune.args) %>%
  as.character()
fitted_models <- enm_model %>% read_rds()

maxent_model <- fitted_models[[model_bestAICc[1]]]
bio_vars <- names(maxent_model@presence)
selected_vars_id <- bio_vars %>%
  stringr::str_split('_') %>%
  purrr::map_chr(-1) %>%
  stringr::str_c("_", .) %>%
  stringr::str_c(collapse = "|")

select_masks <- future_conditions %>%
  purrr::map(names) %>%
  purrr::map(stringr::str_ends, pattern=selected_vars_id)

future_conditions <- future_conditions %>%
  purrr::map2(select_masks, \(x, y) x[[y]])

future_conditions %>%
  purrr::map(terra::set.names, bio_vars)

# t <- future_conditions %>%
#   dismo::predict(maxent_model, .)
#
# # Draft ----
# fitted_models <- "/home/jbarrios/Projects/BeeTool-Bee_DM/done/single_model/BOMHUN/Maxent_models.Rds" %>%
#   read_rds()
# result_models <- "/home/jbarrios/Projects/BeeTool-Bee_DM/done/single_model/BOMHUN/enmeval_results.csv" %>%
#   read_csv()
#
# # fitted_models <- "/home/jbarrios/Projects/BeeTool-Bee_DM/done/ANDALI/Maxent_models.Rds" %>%
# #   read_rds()
# # result_models <- "/home/jbarrios/Projects/BeeTool-Bee_DM/done/ANDALI/enmeval_results.csv" %>%
# #   read_csv()
#
# future_raster <- "./data/future_worldclim/wc2.1_2.5m_bioc_BCC-CSM2-MR_ssp245_2021-2040.tif" %>%
#   rast()
#
# aoi <- "./data/aoi/norteamerica.shp" %>% vect()
#
# model_bestAICc <- result_models %>%
#   filter(delta.AICc == 0) %>%
#   pull(tune.args) %>%
#   as.character()
#
# maxent_model <- fitted_models[[model_bestAICc[1]]]
# bio_vars <- names(maxent_model@presence)
# selected_vars_id <- bio_vars %>%
#   stringr::str_split('_') %>%
#   purrr::map_chr(-1) %>%
#   stringr::str_c("_", .) %>%
#   stringr::str_c(collapse = "|")
#
# select_mask <- names(future_raster) %>%
#   stringr::str_ends(selected_vars_id)
#
# future_raster <- future_raster[[select_mask]] %>%
#   crop(aoi)
# names(future_raster) <- bio_vars
#
# future_model <- predict(maxent_model, future_raster)