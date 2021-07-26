#!/bin/bash

## uncomment these lines to re-export basins from GRDC database (250 Mb to download)

# wget ftp://ftp.bafg.de/pub/REFERATE/GRDC/grdc_major_river_basins_shp.zip
# unzip -d shp grdc_major_river_basins_shp.zip
# grdc="shp/grdc_major_river_basins_shp/mrb_basins.shp"
# ogr2ogr -where "RIVER_BASI='INDUS'" shp/INDUS.shp $grdc
# ogr2ogr -where "RIVER_BASI='GANGES'" shp/GANGES.shp $grdc
# ogr2ogr -where "RIVER_BASI='BRAHMAPUTRA'" shp/BRAHMAPUTRA.shp $grdc

# equal area projection centered in HMA region
projEqArea="+proj=aea +lon_0=82.5 +lat_1=29.1666667 +lat_2=41.8333333 +lat_0=35.5 +datum=WGS84 +units=m +no_defs"

# GTiff compression option for OTB applications
opt="?&gdal:co:COMPRESS=DEFLATE"

# variable loop
for v in "SUBLIM" "SNOWMELT"
do

    # HMASR files were downloaded from NSIDC to this folder
    pin="/media/data/HMA/${v}"

    # rearrange original netcdf files to be GDAL compatible (https://gis.stackexchange.com/a/377498)
    pout=${pin}"transposed/"
    mkdir -p ${pout}
    #parallel ncpdq -a Latitude,Longitude {} ${pout}{/} ::: $(ls ${pin}/*.nc)

    # mosaicing all tiles of 1° latitude by 1° longitude into a single virtual raster
    #parallel gdalbuildvrt $pout/HMA_SR_D_v01_WY{}_${v}.vrt $pout/*WY{}*nc ::: $(seq 2000 2016)

    # compute statistics by basin 
    for BV in "INDUSMOD" "INDUS" "BRAHMAPUTRA" "GANGES" 
    do
        # regrid to equal area projection before aggregrating (nearest neighbor method to accelerate processing)
        #parallel -j1 gdalwarp -multi -wo NUM_THREADS=ALL_CPUS -co COMPRESS=DEFLATE -s_srs EPSG:4326 --config GDALWARP_IGNORE_BAD_CUTLINE YES -r near -t_srs "'"${projEqArea}"'" -crop_to_cutline -cutline shp/$BV.shp $pout/HMA_SR_D_v01_WY{}_${v}.vrt $pout/HMA_SR_D_v01_WY{}_${v}_${BV}.tif ::: $(seq 2000 2016)

        # compute stats from valid pixels (gdalinfo is faster than numpy, easier than dask/xarray)
        #parallel gdalinfo -stats ::: $pout/HMA_SR_D_v01*${v}_${BV}.tif

        # count valid pixels (vpc) in the basin using (here we need python)
        f=$(ls $pout/HMA_SR_D_v01_WY*_${v}_${BV}.tif | head -n1)
        vpc=$(python -c "import gdal; a=gdal.Open('${f}'); print((a.GetRasterBand(1).ReadAsArray()!=-999).sum())")

        # area of a pixel in m2
        pixArea=$(gdalinfo $f | grep "Pixel Size" | cut -d= -f2 | tr "," "*" | tr -d "-" | bc)

        # basin area in km2
        basinArea=$(ogrinfo shp/$BV.shp -al -geom=SUMMARY | grep "AREA_CALC (Real) =" | cut -d= -f2)

        # export data to tables
        mkdir -p tables

        # integrate the daily flux over the valid pixels (e.g. snowmelt was provided in mm/day, hence divide by 1e3 to have m3/day)
        f=HMA_SR_D_v01_DAYM3_${v}_${BV}.csv
        # first fill a column with the DOY
        for i in $(seq 1 366); do echo $i ; done > tmp0
        # get mean daily value from metadata
        for i in $(seq 2000 2016); do
            gdalinfo $pout/HMA_SR_D_v01_WY${i}_${v}_${BV}.tif | grep "STATISTICS_MEAN" | cut -d= -f2 | awk -v c="$vpc" -v a="$pixArea" '{print $1 * c * a / 1e3}' > tmp1
            paste -d" " tmp0 tmp1 > tmp2 && mv -f tmp2 tmp0
        done
        # add the years as a header to the table
        echo " "$(seq 2000 2016) | cat - tmp0 > tables/$f

        # export time cumulated specific flux in mm from 1 to 366
        f=HMA_SR_D_v01_MMCUM_${v}_${BV}.csv
        for i in $(seq 1 366); do echo $i ; done > tmp0
        for i in $(seq 2000 2016); do
            gdalinfo $pout/HMA_SR_D_v01_WY${i}_${v}_${BV}.tif | grep "STATISTICS_MEAN" | cut -d= -f2 | awk -v c="$vpc" -v a="$pixArea" -v b="$basinArea" '{print s+=$1 * c * a / b / 1e6}' > tmp1
            paste -d" " tmp0 tmp1 > tmp2 && mv -f tmp2 tmp0
        done
        echo " "$(seq 2000 2016) | cat - tmp0 > tables/$f

        # compute annual flux in mm from daily values (daily multiband raster to single band raster) - excluding the last day of leap water year 
        exp1=$(for i in $(seq 1 364); do echo -n "im1b${i}+" ; done && echo -n "im1b365")
        parallel otbcli_BandMath -il {} -exp $exp1 -out '"{.}_sum.tif${opt}"' ::: $(ls ${pout}/"HMA_SR_D_v01"*${v}_${BV}.tif )

        # average annual fluxes (17 single band rasters to one single band raster)
        exp2=$(for i in $(seq 1 15); do echo -n "im${i}b1+" ; done && echo -n "im16b1")
        # creates temporary file
        otbcli_BandMath -il $(ls $pout/"HMA_SR_D_v01"*${v}_${BV}"_sum.tif") -exp "("$exp2")/17" -out /tmp/"HMA_SR_D_v01_"${v}_${BV}"_avgmmyr_tmp.tif"
        # manage nodata (initially set to -999)
        otbcli_BandMath -il /tmp/"HMA_SR_D_v01_"${v}_${BV}"_avgmmyr_tmp.tif" -exp "im1b1 > -999 ? im1b1 : -999" -out ${pout}/"HMA_SR_D_v01_"${v}_${BV}"_avgmmyr.tif${opt}"

    done

done
# remove tmp files
rm -f tmp* /tmp/HMA*tif
