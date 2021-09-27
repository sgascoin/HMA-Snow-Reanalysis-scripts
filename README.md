## Scripts to extract basin-scale information from the High Mountain Asia UCLA Daily Snow Reanalysis

- [hmasr-mosaic.sh](hmasr-mosaic.sh): bash script to merge tiles, crop the data to river basins and compute stats. Results are exported as tables in the table folder. River basins are stored in the shp folder.
- [hmasr-plot.ipynb](hmasr-plot.ipynb): Python 3 notebook to plot the output of hmasr-mosaic.sh
- [hmasr-maxsnowmeltdate.py](hmasr-maxsnowmeltdate.py): Python 3 script to compute median date of max snowmelt (dependency: rasterio)

## Publication 
Gascoin S. Snowmelt and Snow Sublimation in the Indus Basin. Water. 2021; 13(19):2621. https://doi.org/10.3390/w13192621

## Data source
Liu, Y., Y. Fang, and S. A. Margulis. 2021. High Mountain Asia UCLA Daily Snow Reanalysis, Version 1. Boulder, Colorado USA. NASA National Snow and Ice Data Center Distributed Active Archive Center. <https://doi.org/10.5067/HNAUGJQXSCVU>. [01 July 2021]. 
