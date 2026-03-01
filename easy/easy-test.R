
library(terra)
library(geodata)

# Set up caching
local_cache <- file.path(getwd(), "geodata_cache")
cache_path <- ifelse(dir.exists(local_cache), local_cache, 
                     tools::R_user_dir("geodata", which = "cache"))
dir.create(cache_path, showWarnings = FALSE, recursive = TRUE)

# downloading and extracting BIO1
worldclim_bio <- geodata::worldclim_global(var = "bio", res = 10, path = cache_path)
bio1_global <- worldclim_bio[[1]]

# crop to South America
south_america_bbox <- terra::ext(-82, -34, -56, 13)
bio1_south_america <- terra::crop(bio1_global, south_america_bbox)

# statistics
bio1_stats <- terra::global(bio1_south_america, fun = c("min", "max", "mean", "std"))
print(bio1_stats)

# plots
plot(bio1_global, main = "Global BIO1")
plot(bio1_south_america, main = "BIO1 - South America")
