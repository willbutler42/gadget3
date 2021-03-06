## -----------------------------------------------------------------------------
##
## Fleet actions:
##
## -----------------------------------------------------------------------------

## Bounded parameters for fleet suitabilities
l50 <- ~bounded(fleet_l50, 40, 100)               #~avoid_zero(fleet_l50)
igfs.l50 <- ~bounded(fleet_l50, 20, 50)
alpha <- ~bounded(fleet_alpha, 0.01, 1)

## List of alpha and l50 for each fleet
fleet_params <- list(
  
  lln_alpha = g3_stock_param(species_name, param="lln.alpha"),
  lln_l50 = g3_stock_param(species_name, param="lln.l50"),
  
  bmt_alpha = g3_stock_param(species_name, param="bmt.alpha"),
  bmt_l50 = g3_stock_param(species_name, param="bmt.l50"),
  
  gil_alpha = g3_stock_param(species_name, param="gil.alpha"),
  gil_l50 = g3_stock_param(species_name, param="gil.l50"),
  
  igfs_alpha = g3_stock_param(species_name, param="igfs.alpha"),
  igfs_l50 = g3_stock_param(species_name, param="igfs.l50")
  
)

## Define actions
fleet_actions <-
  list(
    lln %>%
      g3a_predate_totalfleet(list(ling_imm, ling_mat),
                             suitabilities = list(
                               ling_imm = g3_suitability_exponentiall50(
                                 gadget3:::f_substitute(alpha, list(fleet_alpha = fleet_params[['lln_alpha']])),
                                 gadget3:::f_substitute(l50, list(fleet_l50 = fleet_params[['lln_l50']]))),
                               
                               ling_mat = g3_suitability_exponentiall50(
                                 gadget3:::f_substitute(alpha, list(fleet_alpha = fleet_params[['lln_alpha']])),
                                 gadget3:::f_substitute(l50, list(fleet_l50 = fleet_params[['lln_l50']])))),
                             
                             amount_f = g3_timeareadata('lln_landings', lln_landings[[1]] %>%
                                                          mutate(area = as.numeric(area),
                                                                 step = as.numeric(step),
                                                                 year = as.numeric(year)))),
    
    bmt %>%
      g3a_predate_totalfleet(list(ling_imm, ling_mat),
                             suitabilities = list(
                               ling_imm = g3_suitability_exponentiall50(
                                 gadget3:::f_substitute(alpha, list(fleet_alpha = fleet_params[['bmt_alpha']])),
                                 gadget3:::f_substitute(l50, list(fleet_l50 = fleet_params[['bmt_l50']]))),
                               
                               ling_mat = g3_suitability_exponentiall50(
                                 gadget3:::f_substitute(alpha, list(fleet_alpha = fleet_params[['bmt_alpha']])),
                                 gadget3:::f_substitute(l50, list(fleet_l50 = fleet_params[['bmt_l50']])))),
                             
                             amount_f = g3_timeareadata('bmt_landings', bmt_landings[[1]] %>%
                                                          mutate(area = as.numeric(area),
                                                                 step = as.numeric(step),
                                                                 year = as.numeric(year)))),
    
    gil %>%
      g3a_predate_totalfleet(list(ling_imm, ling_mat),
                             suitabilities = list(
                               ling_imm = g3_suitability_exponentiall50(
                                 gadget3:::f_substitute(alpha, list(fleet_alpha = fleet_params[['gil_alpha']])),
                                 gadget3:::f_substitute(l50, list(fleet_l50 = fleet_params[['gil_l50']]))),
                               
                               ling_mat = g3_suitability_exponentiall50(
                                 gadget3:::f_substitute(alpha, list(fleet_alpha = fleet_params[['gil_alpha']])),
                                 gadget3:::f_substitute(l50, list(fleet_l50 = fleet_params[['gil_l50']])))),
                             
                             amount_f = g3_timeareadata('gil_landings', gil_landings[[1]] %>%
                                                          mutate(area = as.numeric(area),
                                                                 step = as.numeric(step),
                                                                 year = as.numeric(year)))),
    
    foreign %>%
      g3a_predate_totalfleet(list(ling_imm, ling_mat),
                             suitabilities = list(
                               ling_imm = g3_suitability_exponentiall50(
                                 gadget3:::f_substitute(alpha, list(fleet_alpha = fleet_params[['lln_alpha']])),
                                 gadget3:::f_substitute(l50, list(fleet_l50 = fleet_params[['lln_l50']]))),
                               
                               ling_mat = g3_suitability_exponentiall50(
                                 gadget3:::f_substitute(alpha, list(fleet_alpha = fleet_params[['lln_alpha']])),
                                 gadget3:::f_substitute(l50, list(fleet_l50 = fleet_params[['lln_l50']])))),
                             
                             amount_f = g3_timeareadata('foreign_landings', foreign_landings[[1]] %>%
                                                          mutate(area = as.numeric(area),
                                                                 step = as.numeric(step),
                                                                 year = as.numeric(year)))),
    
    igfs %>%
      g3a_predate_totalfleet(list(ling_imm, ling_mat),
                             suitabilities = list(
                               ling_imm = g3_suitability_exponentiall50(
                                 gadget3:::f_substitute(alpha, list(fleet_alpha = fleet_params[['igfs_alpha']])),
                                 gadget3:::f_substitute(igfs.l50, list(fleet_l50 = fleet_params[['igfs_l50']]))),
                               
                               ling_mat = g3_suitability_exponentiall50(
                                 gadget3:::f_substitute(alpha, list(fleet_alpha = fleet_params[['igfs_alpha']])),
                                 gadget3:::f_substitute(igfs.l50, list(fleet_l50 = fleet_params[['igfs_l50']])))),
                             
                             amount_f = g3_timeareadata('igfs_landings', igfs_landings %>%
                                                          mutate(area = as.numeric(area),
                                                                 step = as.numeric(step),
                                                                 year = as.numeric(year)))))
