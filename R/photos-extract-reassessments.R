##move the photos and spreadsheet ready for submission to pscis
source('R/packages.R')
source('R/functions.R')
# source('R/tables.R')


##here we back everything up to the D drive
targetdir = paste0("D:/PSCIS_elk_2020_reassessments/")
dir.create(targetdir)


##path to the photos
path <- paste0(getwd(), '/data/photos')


##use the pscis spreadsheet to make the folders to copy the photos to
pscis_file_name <- 'pscis_reassessments.xlsm'

d <- import_pscis(workbook_name = pscis_file_name)

folderstocopy<- d$pscis_crossing_id %>% as.character()

path_to_photos <- paste0(getwd(), '/data/photos/', folderstocopy)

folderstocreate<- paste0(targetdir, folderstocopy)

##create the folders
lapply(folderstocreate, dir.create)


paths_to_copy <- function(target){
  list.files(path = target,
             pattern = ".JPG$",
             recursive = TRUE,
             full.names = T,
             include.dirs = T) %>%
    stringr::str_subset(., 'barrel|outlet|upstream|downstream|road|inlet|_k_')
}

photo_names_to_copy <- function(target){
  list.files(path = target,
             pattern = ".JPG$",
             recursive = TRUE,
             full.names = F,
             include.dirs = T) %>%
    stringr::str_subset(., 'barrel|outlet|upstream|downstream|road|inlet|_k_')
}


filestocopy_list <- path_to_photos %>%
  purrr::map(paths_to_copy)

change_file_names <- function(filenames_to_change){
  gsub(filenames_to_change, pattern = paste0(getwd(), '/data/photos/'), replacement = targetdir)
}

filestopaste_list <- filestocopy_list %>%
  map(change_file_names)

# filestopaste_list <- path_to_photos %>%
#   purrr::map2(paths_to_copy)

copy_over_photos <- function(filescopy, filespaste){
  file.copy(from=filescopy, to=filespaste,
            overwrite = T,
            copy.mode = TRUE)
}

mapply(copy_over_photos, filescopy =  filestocopy_list,
       filespaste = filestopaste_list)

##also move over the pscis file
file.copy(from = paste0('data/', pscis_file_name), to = paste0(targetdir, pscis_file_name))

##zip them all together to give to betty
##now we will zip up the files in the data folder and rename with kmz
files_to_zip <- paste0("D:/", list.files(path = "D:/", pattern = "*PSCIS_elk*"))
zip::zipr(paste0("D:/", 'PSCIS_elk.zip'), files = files_to_zip)


