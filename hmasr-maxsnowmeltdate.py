# compute median date of max daily snowmelt
# todo: switch to xarray/dask pipeline

import rasterio
import numpy as np

!mkdir -p figs
pin ='/media/data/HMA/'
BV = 'INDUSMOD'
v = 'SNOWMELT'

# write an annual argmax raster from each stack of daily snowmelt maps
for y in range(2000,2017):
    fname = f"{pin}{v}transposed/HMA_SR_D_v01_WY{y}_{v}_{BV}.tif"
    with rasterio.open(fname) as src:
        ds = src.read()
        am = ds.argmax(axis=0)
        with rasterio.Env():
            profile = src.profile
            profile.update(dtype=rasterio.uint16,count=1,compress='deflate',nodata=0)
            with rasterio.open(f"figs/HMA_SR_D_v01_WY{y}_{v}_{BV}_argmax.tif", 'w', **profile) as dst:
                dst.write(am.astype(rasterio.uint16), 1)

# stack annual argmax date files to a single raster
!gdalbuildvrt -separate argmax.vrt figs/*argmax.tif

# compute median 
with rasterio.open('argmax.vrt') as src:
    ds = src.read()
    a = np.median(ds, axis=0)                
    with rasterio.open(f"figs/HMA_SR_D_v01_{v}_{BV}_argmax_median.tif", 'w', **profile) as dst:
        dst.write(a.astype(rasterio.uint16), 1)