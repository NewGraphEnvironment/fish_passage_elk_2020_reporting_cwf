source('R/packages.R')
source('R/functions.R')
source('R/tables.R')
source('R/tables-phase2.R')

## we need to screen out the crossings that are not matched well

# make_tab_cost_est_phase1 <- function(dat = pscis){
bcfishpass_rd <- bcfishpass_phase2 %>%
  select(pscis_crossing_id, my_crossing_reference, crossing_id, distance, road_name_full,
         road_class, road_name_full, road_surface, file_type_description, forest_file_id,
         client_name, client_name_abb, map_label, owner_name, admin_area_abbreviation,
         wct_network_km, wct_belowupstrbarriers_network_km,distance) %>%
  # mutate(uphab_net_sub22 = rowSums(select(., uphab_l_net_inf_000_030:uphab_l_net_obs_150_220))) %>%
  filter(distance < 100) %>%
  select(pscis_crossing_id:admin_area_abbreviation, wct_network_km, wct_belowupstrbarriers_network_km)


##trying to fix the missed matches
dups <- c(4600183, 4600069, 4600367, 4605732, 4600070)

match_this <- xref_pscis_my_crossing_modelled %>%
  filter(my_crossing_reference %in% dups) %>%
  purrr::set_names(nm = paste0('x_', names(.))) %>%
  mutate(x_my_crossing_reference = as.numeric(x_my_crossing_reference))

bcfishpass_rd <- left_join(
  bcfishpass_rd,
  match_this,
  by = c('pscis_crossing_id' = 'x_stream_crossing_id')
) %>%
  mutate(my_crossing_reference =
           case_when(is.na(my_crossing_reference) & !is.na(x_my_crossing_reference) ~ x_my_crossing_reference,
                     T ~ my_crossing_reference)) %>%
  select(-x_my_crossing_reference, -x_misc_point_id, -x_crossing_id)


# bcfishpass_rd <- bcfishpass_rd %>%

## updated to new bcfishpass info
# bcfishpass_rd <- bcfishpass_phase2 %>%
#   select(pscis_crossing_id, my_crossing_reference, crossing_id, distance, road_name_full,
#          road_class, road_name_full, road_surface, file_type_description, forest_file_id,
#          client_name, client_name_abb, map_label, owner_name, admin_area_abbreviation,
#          uphab_l_net_inf_000_030:uphab_gross_sub22, distance) %>%
#   mutate(uphab_net_sub22 = rowSums(select(., uphab_l_net_inf_000_030:uphab_l_net_obs_150_220))) %>%
#   filter(distance < 100) %>%
#   select(my_crossing_reference:admin_area_abbreviation, uphab_gross_sub22, uphab_net_sub22)




###note that some of the rd info is not likely correct if the distance is >100m
pscis_rd <- left_join(
  pscis,
  bcfishpass_rd,
  by = c('my_crossing_reference')
) %>%
  dplyr::mutate(my_road_class = case_when(is.na(road_class) & !is.na(file_type_description) ~
                                            file_type_description,
                                          T ~ road_class)) %>%
  dplyr::mutate(my_road_class = case_when(is.na(my_road_class) & !is.na(owner_name) ~
                                            'rail',
                                          T ~ my_road_class)) %>%
  dplyr::mutate(my_road_surface = case_when(is.na(road_surface) & !is.na(file_type_description) ~
                                              'loose',
                                            T ~ road_surface)) %>%
  dplyr::mutate(my_road_surface = case_when(is.na(my_road_surface) & !is.na(owner_name) ~
                                            'rail',
                                          T ~ my_road_surface)) %>%
    select(rowname:road_name, file_type_description, owner_name, road_surface,  road_class, my_road_class, everything())


# test <- pscis_rd %>% filter(my_crossing_reference == 4605732)

####----tab cost multipliers for road surface-----
tab_cost_rd_mult <- pscis_rd %>%
  select(my_road_class, my_road_surface) %>%
  # mutate(road_surface_mult = NA_real_, road_class_mult = NA_real_) %>%
  mutate(road_class_mult = case_when(my_road_class == 'local' ~ 4,
                                     my_road_class == 'collector' ~ 4,
                                     my_road_class == 'arterial' ~ 20,
                                     my_road_class == 'highway' ~ 20,
                                     my_road_class == 'rail' ~ 20,
                                     T ~ 1))  %>%
  mutate(road_surface_mult = case_when(my_road_surface == 'loose' ~ 1,
                                       my_road_surface == 'rough' ~ 1,
                                       my_road_surface == 'rail' ~ 2,
                                       my_road_surface == 'paved' ~ 2)) %>%
  # mutate(road_type_mult = road_class_mult * road_surface_mult) %>%
  mutate(cost_m_1000s_bridge = road_surface_mult * road_class_mult * 12.5,
         cost_embed_cv = road_surface_mult * road_class_mult * 25) %>%
  # mutate(cost_1000s_for_10m_bridge = 10 * cost_m_1000s_bridge) %>%
  distinct( .keep_all = T) %>%
  arrange(cost_m_1000s_bridge, my_road_class)
  # readr::write_csv(file = paste0(getwd(), '/data/raw_input/tab_cost_rd_mult.csv')) %>%
# kable() %>%
# kable_styling(latex_options = c("striped", "scale_down")) %>%
# kableExtra::save_kable("fig/tab_cost_rd_mult.png")


####-----------report table--------------------
tab_cost_rd_mult_report <- tab_cost_rd_mult %>%
  mutate(cost_m_1000s_bridge = cost_m_1000s_bridge * 10) %>%
  rename(
    Class = my_road_class,
    Surface = my_road_surface,
    `Class Multiplier` = road_class_mult,
    `Surface Multiplier` = road_surface_mult,
    `Bridge $K/10m` = cost_m_1000s_bridge,
    `Streambed Simulation $K` = cost_embed_cv
  ) %>%
  filter(!is.na(Class)) %>%
  mutate(Class = stringr::str_to_title(Class),
         Surface = stringr::str_to_title(Surface)
         )



##make the cost estimates
tab_cost_est_prep <- left_join(
  select(pscis_rd, my_crossing_reference, stream_name, road_name, habitat_value, my_road_class,
         my_road_surface, downstream_channel_width_meters, barrier_result, final_score,
         fill_depth_meters, crossing_fix,  habitat_value, recommended_diameter_or_span_meters),
  select(tab_cost_rd_mult, my_road_class, my_road_surface, cost_m_1000s_bridge, cost_embed_cv),
  by = c('my_road_class','my_road_surface')
)

# tab_cost_est_prep <- left_join(
#   select(pscis_rd, my_crossing_reference, stream_name, road_name, my_road_class,
#          my_road_surface, downstream_channel_width_meters, barrier_result,
#          fill_depth_meters, crossing_fix, , habitat_value, recommended_diameter_or_span_meters),
#   select(tab_cost_rd_mult, my_road_class, my_road_surface, cost_m_1000s_bridge, cost_embed_cv),
#   by = c('my_road_class','my_road_surface')
# )




tab_cost_est_prep2 <- left_join(
  tab_cost_est_prep,
  select(xref_structure_fix, crossing_fix, crossing_fix_code),
  by = c('crossing_fix')
) %>%
  mutate(cost_est_1000s = case_when(
    crossing_fix_code == 'SS-CBS' ~ cost_embed_cv,
    crossing_fix_code == 'OBS' ~ cost_m_1000s_bridge * recommended_diameter_or_span_meters)
  ) %>%
  mutate(cost_est_1000s = round(cost_est_1000s, 0))

##add in the model data.  This is a good reason for the data to be input first so that we can use the net distance!!
tab_cost_est_prep3 <- left_join(
  tab_cost_est_prep2,
  select(bcfishpass_rd, my_crossing_reference,  wct_network_km, wct_belowupstrbarriers_network_km),
  by = c('my_crossing_reference' = 'my_crossing_reference')
) %>%
  mutate(cost_net = round(wct_belowupstrbarriers_network_km * 1000/cost_est_1000s, 1),
         cost_gross = round(wct_network_km * 1000/cost_est_1000s, 1),
         cost_area_net = round((wct_belowupstrbarriers_network_km * 1000 * downstream_channel_width_meters)/cost_est_1000s, 1), ##this is a triangle area!
         cost_area_gross = round((wct_network_km * 1000 * downstream_channel_width_meters)/cost_est_1000s, 1)) ##this is a triangle area!

##add the xref stream_crossing_id
tab_cost_est_prep4 <- left_join(
  tab_cost_est_prep3,
  xref_pscis_my_crossing_modelled,
  by = 'my_crossing_reference'
)


##add the priority info
tab_cost_est <- left_join(
  tab_cost_est_prep4,
  select(phase1_priorities, my_crossing_reference, priority_phase1),
  by = 'my_crossing_reference'
) %>%

  mutate(wct_network_km = round(wct_network_km,2)) %>%
  arrange(stream_crossing_id) %>%
  mutate(stream_crossing_id = as.character(stream_crossing_id),
         my_crossing_reference = as.character(my_crossing_reference)) %>%
  mutate(ID = case_when(
    !is.na(stream_crossing_id) ~ stream_crossing_id,
    T ~ paste0('*', my_crossing_reference
    ))) %>%
  mutate(barrier_result_score = paste0(barrier_result, ' (', final_score, ')')) %>%
  mutate(`Habitat Value (priority)` = case_when(is.na(habitat_value) |  is.na(priority_phase1) ~ '--',
                                                T ~  paste0(habitat_value, ' (' , priority_phase1, ')'))) %>%
  select(stream_crossing_id, my_crossing_reference, crossing_id, ID, stream_name, road_name, `Habitat Value (priority)`, habitat_value, barrier_result_score, downstream_channel_width_meters, priority_phase1,
         crossing_fix_code, cost_est_1000s, wct_network_km,
         cost_gross, cost_area_gross)

tab_cost_est_phase1 <- tab_cost_est %>%
  select(-stream_crossing_id:-crossing_id, -habitat_value, -priority_phase1) %>%
  rename(
    # `Habitat Value` = habitat_value,
    # Priority = priority_phase1,
    Stream = stream_name,
    Road = road_name,
    `Result (Score)` = barrier_result_score,
    `Stream Width (m)` = downstream_channel_width_meters,
    Fix = crossing_fix_code,
    `Cost Est ( $K)` =  cost_est_1000s,
    `Habitat Upstream (km)` = wct_network_km,
    `Cost Benefit (m / $K)` = cost_gross,
    `Cost Benefit (m2 / $K)` = cost_area_gross) %>%
  mutate(across(everything(), as.character)) %>%
  replace(., is.na(.), "--")


# tab_cost_est_phase1 <- left_join(
#   tab_cost_est,
#   select(bcfishpass_phase2, my_crossing_reference, stream_crossing_id),
#   by = 'my_crossing_reference'
# ) %>%
#   mutate(ID = case_when())
#   select(`PSCIS ID` = stream_crossing_id, everything(), -my_crossing_reference) %>%
#   arrange(`PSCIS ID`)



##clean up workspace
rm(ab_cost_est, tab_cost_est_prep, tab_cost_est_prep2, tab_cost_est_prep3,
   bcfishpass_rd, pscis_rd)
