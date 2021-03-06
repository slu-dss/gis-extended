Part 2 - Completed Version
================
Christopher Prener, Ph.D.
(June 17, 2021)

## Introduction

This notebook expands mapping to a new package, `ggplot2`. We’ll focus
on thematic choropleth mapping with it, though you can make other types
of maps as well. Along the way, we’ll discussing using projected
coordinate systems for mapping.

## Dependencies

This notebook requires a variety of packages for working with spatial
data:

``` r
# tidyverse packages
library(ggplot2)      # plotting

# spatial packages
library(mapview)      # preview spatial data
library(sf)           # spatial data tools
```

    ## Linking to GEOS 3.8.1, GDAL 3.2.1, PROJ 7.2.1

``` r
# other packages
library(here)         # file path management
```

    ## here() starts at /Users/chris/GitHub/slu-dss/gis-extended

``` r
library(RColorBrewer) # color palettes
```

## Working with Spatial Data Files

There are two main types of spatial data files you might run into: \*
“Shapefiles” are a type of file format (actually a collection of files)
that were popularized by ESRI, the makers of the ArcGIS software
platform. These files are very, very common in the GIS world. They
contain both the geometric and tabular data needed to map data. They’re
a bit clunky to work with using your operating system - there can be
over a dozen constituent files, and they all must be named identically.
So, they’re not the most friendly files to work with, but their ubiquity
makes it important to know a bit about how to work with them. \*
“GeoJSON” files are plain text files that contain all of the core
information that shapefiles contain (tabular and geometric data), though
they cannot store some of the more complex metadata that shapefiles can.
They’re far easier to work with, however, because they are a single
plain text file.

### Reading Spatial Data Files

For data that have already been converted to geometric data, we use the
`sf` package to read them. The importing process looks similar to what
we used with the `.csv` file. It is the same process regardless of
whether you have a shapefile or a GeoJSON file.

We’ll demonstrate this with COVID-19 data for Chicago at the ZIP code
level:

``` r
covid <- st_read(here("data", "chicago_covid.geojson"))
```

    ## Reading layer `chicago_covid' from data source `/Users/chris/GitHub/slu-dss/gis-extended/data/chicago_covid.geojson' using driver `GeoJSON'
    ## Simple feature collection with 61 features and 5 fields
    ## Geometry type: MULTIPOLYGON
    ## Dimension:     XY
    ## Bounding box:  xmin: -87.94011 ymin: 41.64454 xmax: -87.52414 ymax: 42.02304
    ## Geodetic CRS:  WGS 84

We’ll still use `here()` to specify the file path, but the function is
different now because we need a specialized tool for geometric data.

Now, you repeat this process for the `chicago_black_pop.geojson`, which
is stored in the same directory:

``` r
black <- st_read(here("data", "chicago_black_pop.geojson"))
```

    ## Reading layer `chicago_black_pop' from data source `/Users/chris/GitHub/slu-dss/gis-extended/data/chicago_black_pop.geojson' using driver `GeoJSON'
    ## Simple feature collection with 1319 features and 6 fields (with 1 geometry empty)
    ## Geometry type: MULTIPOLYGON
    ## Dimension:     XY
    ## Bounding box:  xmin: -88.26364 ymin: 41.46971 xmax: -87.52416 ymax: 42.15426
    ## Geodetic CRS:  NAD83

This file contains Census tract level estimates of the Black population
in Chicago from the latest edition of the American Community Survey’s
2015-2019 five-year estimates.

Finally, we’ll read in a shapefile containing the City of Chicago’s
boundary:

``` r
city <- st_read(here("data", "chicago_boundary", "chicago_boundary.shp"))
```

    ## Reading layer `chicago_boundary' from data source `/Users/chris/GitHub/slu-dss/gis-extended/data/chicago_boundary/chicago_boundary.shp' using driver `ESRI Shapefile'
    ## Simple feature collection with 1 feature and 4 fields
    ## Geometry type: MULTIPOLYGON
    ## Dimension:     XY
    ## Bounding box:  xmin: -87.94011 ymin: 41.64454 xmax: -87.52414 ymax: 42.02304
    ## Geodetic CRS:  WGS84(DD)

Notice that we specify the `.shp` file, which is one of four files that
accompany our shapefile collection.

### Previewing Data

Once we have our data read in, we can start to explore it. First, take a
moment to use `View()` (or click on each of the objects in your global
environment) to check out their structure and get a sense of the
different columns. Next, lets use `mapview` to explore our data:

``` r
mapview(covid)
```

![](part-2-complete_files/figure-gfm/preview-covid-1.png)<!-- -->

Now, you repeat this process with the Part 1 crime data for Shaw:

``` r
mapview(black)
```

![](part-2-complete_files/figure-gfm/preview-black-1.png)<!-- -->

### Prepping Our Data

In order to map our data properly, we need to “transform” our data to a
*projected coordinate system*. As we did in the first part, we’ll use
the `sf` package’s `st_transform()` function to do this. Before we make
the transformation, we should understand both what a projected
coordinate system is and how we pick one.

Projected coordinate systems provide us with a mathematical
transformation of our geographic coordinate system data, which are based
on a spherical model of the earth, to a two-dimensional space. Since our
computers and printed maps both render data in two-dimensions, we need
to do this to deal with the distortions that come from viewing our
geographic coordinate system data in two-dimensions. The key lesson here
is that *we should always map in a projected coordinate system*.

There are different types of projected coordinate systems for specific
parts of the world. Different systems make these mathematical
transformations in different ways. So, we ultimately end up having to
pick from what seems at first blush to be a relatively large menu of
coordinate systems. In the United States, at the local level, most
analysts select either the state plane or UTM coordinate systems.
Chicago falls into the Illinois East State Plane region, whose 2007
updates are referred to using the EPSG code `3528`.

Coordinate systems are perhaps the most complex, and therefore most
misunderstood, part of mapping. If you switch to mapping different
regions, or change the scale (state-wide mapping, regional mapping,
national mapping, global mapping), you’ll have to also change the
projected coordinate system you use.

To make our transformations, we’ll use `st_transform()` paired with our
selected EPSG code for the COVID data:

``` r
covid <- st_transform(covid, crs = 3528)
```

Now, you try this syntax out on the demographic data and:

``` r
black <- st_transform(black, crs = 3528)
```

Finally, we need to transform our city boundary data as well:

``` r
city <- st_transform(city, crs = 3528)
```

It is important to get all of your `sf` objects that will be mapped
together into the same projected coordinate system!

## Simple Maps with `ggplot2`

### Basic Mapping of Geometric Objects

`ggplot2` is the premier graphics package for `R`. It is an incredibly
powerful visualization tool that increasingly supports spatial work and
mapping. The basic `ggplot2` workflow requires chaining together
functions with the `+` sign.

We’ll start by creating a `ggplot2` object with the `ggplot()` function,
and then adding a “geom”, which provides `ggplot2` instructions on how
our data should be visualized. We can read these like paragraphs:

1.  First, we create an empty `ggplot2` object, **then**
2.  we add the `covid` data and visualize its geometry.

``` r
ggplot() +
  geom_sf(data = covid, fill = "#bababa")
```

![](part-2-complete_files/figure-gfm/ggplot2-covid-1.png)<!-- -->

The color abbreviation we use is called a “hex decimal” - it is a
symbolic representation of a color model that helps us pick specific
colors for our plots. I rely on the website
[ColorHexa](http://colorhexa.com) to help select hex decimal values.

We can also add the `city` layer on top to give the city border a
pronounced outline. `ggplot2` relies on layering different geoms to
produce complicated plots. We can assign each geom a specific set of
aesthetic characteristics and use data from different objects.

``` r
ggplot() +
  geom_sf(data = covid, fill = "#bababa") +
  geom_sf(data = city, fill = NA, color = "#000000", size = .75)
```

![](part-2-complete_files/figure-gfm/ggplot2-covid-2-1.png)<!-- -->

These ZIP code boundaries were created by the City of Chicago, and
represent generalizations of where ZIP codes are located. The challenge
with working with ZIP codes is that they are not actually polygons on a
map, but rather lines that represent distinct carrier routes. Because of
this, USPS does not publish an authoritative shapefile of ZIP code
boundaries. Some places, like Chicago, make their own. In many parts of
the country, we use the Census Bureau’s ZIP Code Tabulation Areas
(ZCTAs) instead. There are many challenges to working with ZIP code
data, and they should be used as a geography of last resort.
Unfortunately, they are also the most common data we can collect from
individuals because most people know the ZIP code they live in. This
tension has been written about extensively in geography.

Now it is your turn - re-create this process but map zip codes using the
`black` data and use the city boundaries in `city`:

``` r
ggplot() +
  geom_sf(data = black, fill = "#bababa") +
  geom_sf(data = city, fill = NA, color = "#000000", size = .75)
```

![](part-2-complete_files/figure-gfm/ggplot2-black-1.png)<!-- -->

Notice that our data don’t line up well. This is one of the complexities
of working with Census data. Spatial data that they provide are at the
county-level, so in this case we have Cook County’s Census tracts.
Census tract boundaries do not always respect municipal boundaries, and
so some Census tracts will cross between Chicago and neighboring
municipalities.

### Mapping Quantities with `ggplot2`

If we wanted to start to map data instead of just the geometric
properties, we would specify an “aesthetic mapping” using
`mapping= aes()` in the geom of interest. Here, we create a fill that is
the product of taking the 2019 Black population’s rate.

We always want to map per capita rates, and not the raw counts. If we do
not have a population denominator, like with total population, we can
map density instead by using area as our denominator. Either approach is
acceptable, but it is critical that you use some form of normalization.
Otherwise, you may simply find yourself making a map of where people
live, instead of your phenomenon of interest. Alternatively, you may
make a map that draws readers’ eyes towards the largest geographic
areas. Neither is a good outcome!

We provide additional instructions about how our data should be colored
with the `scale_fill_distiller()` function, which gives us access to the
`RColorBrewer` palettes.

``` r
## create plot
p1 <- ggplot() +
  geom_sf(data = black, mapping = aes(fill = black_rate), size = .05) +
  geom_sf(data = city, fill = NA, color = "#000000", size = .75) +
  scale_fill_distiller(palette = "Greens", trans = "reverse", name = "Population per 1,000") +
  labs(
    title = "Per Capita Black Population (2019)",
    subtitle = "Tracts in Cook County, IL",
    caption = "Map by Christopher Prener, Ph.D."
  ) +
  theme_minimal() 

## print plot
p1
```

![](part-2-complete_files/figure-gfm/ggplot2-black-choro-1.png)<!-- -->

Replicate this process, using the `case_rate` or `death_rate` column in
`covid` to plot the already normalized numbers of cases per 100,000
people in each zip code:

``` r
## create plot
p2 <- ggplot() +
  geom_sf(data = covid, mapping = aes(fill = case_rate), size = .25) +
  geom_sf(data = city, fill = NA, color = "#000000", size = .75) +
  scale_fill_distiller(palette = "RdPu", trans = "reverse", name = "Cases Per 1,000 People") +
  labs(
    title = "Reported COVID-19 Cases",
    subtitle = "ZIP Codes in Chicago, IL",
    caption = "Map by Christopher Prener, Ph.D."
  ) +
  theme_minimal() 

## print plot
p2
```

![](part-2-complete_files/figure-gfm/ggplot2-covid-choro-1.png)<!-- -->

## Saving Maps

To save our maps, we can use the `ggsave()` function. We’ll refer to the
plot object we created above, `p1`:

``` r
ggsave(filename = here("results", "chicago_black_pop.png"), plot = p1)
```

    ## Saving 7 x 5 in image

Be aware of the other arguments for `ggsave()`, which include the
ability to control the dimensions and dpi of your output.

Now it’s your turn - save the COVID map that you created above:

``` r
ggsave(filename = here("results", "chicago_covid_cases.png"), plot = p2)
```

    ## Saving 7 x 5 in image
