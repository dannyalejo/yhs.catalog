#!/usr/bin/env Rscript --no-save

###
#	to.R
#	/Users/abl/local.projects/HeebDOG/data/earthquakes
#	Created by 
#		/Users/abl/bin/ropen ( v. 2.6.6 )
#	on 
#		2018:073 (14-March)
#
#	[ Loads the SCSN catalog, prepares it, and saves it to R-binary ]
#
###

## local functions
#try(source('funcs.R'))

## libs

suppressPackageStartupMessages({
	library(tools)
	# loads core tidy packages:  ggplot2, tibble, tidyr, readr, purrr, and dplyr
	library(tidyverse)
})

#+++++++++++

shake <- FALSE
redo <- FALSE
inter <- interactive()

fi <- 'catalog_current.fwf.gz'
#       1981 = year
#          1 = month
#          1 = day
#          4 = hour
#         13 = minute
#     55.710 = second
#    3301565 = SCSN cuspid (up to 9 digits)
#   33.25524 = latitude
# -115.96763 = longitude
#      5.664 = depth (km)
#       2.26 = SCSN calculated preferred magnitude (0.0 if unassigned)
#         45 = number of P and S picks used for 1D SSST or 3D location (different from old format)
#         17 =  to nearest statino in km (different from old format)
#       0.21 = rms residual (s) for 1D location; value of 99.0 indicates information not available
#          1 = local day/night flag (=0 for day, =1 for night in Calif.)
#          4 = location method flag (=1 for SCSN catalog or 1d hypoinverse relocation,
#                   =2 for 1D SSST,  =3 for 3D, =4 for waveform cross-correlation)
#        260 = similar event cluster identification number (0 if the event is not relocated with waveform cross-correlation data)
#        460 = number of events in similar event cluster (0 if the event is not in similar event clusters)
#       76 = number of differential times used to locate this event
#      0.300 = est. std. error (km) in absolute horz. position
#      0.800 = est. std. error (km) in absolute depth
#      0.003 = est. std. error (km) in horz. position relative to other events in cluster
#      0.003 = est. std. error (km) in depth relative to other events in cluster
#         le = SCSN flag for event type (le=local, qb=quarry, re=regional)
#         ct = for location method (ct=cross-correlation; 3d=3d velocity model; xx= not relocated, SCSN location used)
#       Poly5= the polygon where the earthquake is located.  We used 5 polygons to
nms <- c('Year','Month','Day','Hour','Minute','Second',
	'CID','Lat.deg','Lon.deg', 'Dep.km', 'Mag', 
	'n.picks', 'nearest.km', 'rms',
	'nighttime', 'locmeth1', 
	'clustid', 'n.clust', 'n.difft', 
	'h.err.km', 'z.err.km', 'rel.h.err', 'rel.z.err',
	'type', 'locmeth2', 'polyg')

if (!exists('scsn.o') | !inter) readr::read_fwf(fi, readr::fwf_empty(fi, col_names=nms)) -> scsn.o

redo.proc <- FALSE
if (!exists('scsn_') | !exists('scsn_arr') | redo.proc){
  scsn.o %>% dplyr::mutate(
    Month = as.numeric(Month),
    Day = as.numeric(Day),
    Hour = as.numeric(Hour),
    Minute = abs(as.numeric(Minute)),
    Minute = ifelse(Minute==60, 59, Minute),
    Second = as.numeric(Second),
    CID = as.character(CID),
    nighttime = as.logical(trimws(nighttime)),
    n.difft = as.integer(n.difft),
    rms = ifelse(rms==99, NA, rms),
    locmeth1 = factor(locmeth1),
    type = factor(type),
    locmeth2 = factor(locmeth2),
    polyg = factor(polyg),
    DateTime = ISOdatetime(Year, Month, Day, Hour, Minute, Second, tz='UTC')
  ) %>% dplyr::arrange(CID) -> scsn_
  
  scsn_ %>% unique %>% dplyr::arrange(DateTime, CID) -> scsn_arr
  
  attr(scsn_arr, 'scsn_assembly') <- list(Date=Sys.time(), SI=sessionInfo())
}

scsn_arr	
summary(scsn_arr)

scsn_arr %>% dplyr::group_by(CID) %>% dplyr::summarize(N=n()) %>% dplyr::filter(N>1) -> nonunique

scsn <- if (nrow(nonunique)>0){
  warning("  --> Does NOT check OK! -- stripping out duplicates:", immediate. = TRUE)
  print(as.data.frame(nonunique))
  dupes. <- nonunique$CID
  scsn_arr %>% dplyr::filter(!(!is.na(rms) & (CID %in% dupes.))) -> scsn_arr2
  #scsn_arr2 %>% dplyr::group_by(CID) %>% dplyr::summarize(N=n()) %>% dplyr::filter(N>1) -> nonunique2
  scsn_arr2
} else {
	message('  --> checks OK')
  scsn_arr
}

if (!all.equal(nrow(nonunique) + nrow(scsn) - nrow(scsn_arr), 0)){
  stop('Something went awry trying to remove duplicates... Check manually')
} else {
  message("(stripping duplicates succeeded...)")
}

#+++++++++++

force.save <- TRUE
if (!inter | force.save){
  rdafi <- 'scsn.rda'
  message('Saving ', rdafi, '...')
  save(scsn, file=rdafi, compress='xz')
  message("Done.")
} else {
  warning("Interactive mode -- no saving for speed purposes")
}
