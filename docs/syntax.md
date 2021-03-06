#####  <a name="Syntax"></a>Syntax

`quantile`: Compute empirical quantiles of a variable with sample data corresponding to given probabilities. 

<hr size="5" style="color:black;background-color:black;" />

######  Common parameterisation

Some arguments are common to the implementations in the different languages:

* `probs` : <a name="probs"></a> (_option_) list of probabilities with values in [0,1]; the smallest observation 
	corresponds to a probability of 0 and the largest to a probability of 1; default: probs is set to the
	sequence `0 0.25 0.5 0.75 1`, so as to match default values `seq(0, 1, 0.25)` used in R 
	[quantile](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/quantile.html); 
* `type` : <a name="type"></a> (_option_) an integer between 1 and 11 selecting one of the 9+1+1 quantile algorithms 
	discussed in Hyndman and Fan's, Cunane's and Filliben's articles (see [references](algorithm.md#References)) 
	and detailed below to be used; 
	
	| `type` |                    description                                 |
	|:------:|:---------------------------------------------------------------|
	|    1   | inverted empirical CDF					  |
	|    2   | inverted empirical CDF with averaging at discontinuities       |       
	|    3   | observation numberer closest to qN (piecewise linear function) | 
	|    4   | linear interpolation of the empirical CDF                      | 
	|    5   | Hazen's model (piecewise linear function)                      | 
	|    6   | Weibull quantile                                               |
	|    7   | interpolation points divide sample range into n-1 intervals    |
	|    8   | unbiased median (regardless of the distribution)               |
	|    9   | approximate unbiased estimate for a normal distribution        |
	|   10   | Cunnane's definition (approximately unbiased)                  |
	|   11   | Filliben's estimate                                            |

	default: `type=7` (likewise R `quantile`);
* `method` : <a name="method"></a> (_option_) choice of the implementation of the quantile estimation method; this can be either:
	+ `INHERIT` for an estimation based on the use of an already existing implementation in 
	the given language,
	+ `DIRECT` for a canonical implementation based on the direct transcription of the various
	quantile estimation algorithms (see below) into the given language;
		
	default: `method=DIRECT`;
* `na_rm` : <a name="na_rm"></a> (_option_) logical; if true, any NA and NaN's are removed from x before the quantiles 
	are computed.

<hr size="5" style="color:black;background-color:black;" />

######  <a name="sas_quantile"></a> `SAS` macro
	
~~~sas
%quantile(var, probs=, type=7, method=DIRECT, names=, _quantiles_=, 
	  idsn=, odsn=, ilib=WORK, olib=WORK, na_rm = YES);
~~~
				
**Arguments**

* `var` : data whose sample quantiles are estimated; this can be either:
	+ the name of the variable in a dataset storing the data; in that case, the parameter 
			`idsn` (see below) should be set; 
	+ a list of (blank separated) numeric values;
* `idsn` : (_option_) when input data is passed as a variable name, `idsn` represents the dataset
	to look for the variable `var` (see above);
* `ilib` : (_option_) name of the input library; by default: empty, _i.e._ `WORK` is used if `idsn` is 
	set;
* `olib` : (_option_) name of the output library (see `names` below); by default: empty, _i.e._ `WORK` 
	is also used when `odsn` is set.

**Returns**
Return estimates of underlying distribution quantiles based on one or two order statistics from 
the supplied elements in `var` at probabilities in `probs`, following quantile estimation algorithm
defined by `type`. The output sample quantile are stored either in a list or as a table, through:

* `_quantiles_` : (_option_) name of the output numeric list where quantiles are stored in increasing
	`probs` order; incompatible with parameters `odsn` and `names `below;
* `odsn, names` : (_option_) respective names of the output dataset and variable where quantiles are 
	stored; if both `odsn` and `names` are set, the quantiles are saved in the `names` variable ot the
	`odsn` dataset; if just `odsn` is set, then they are stored in a variable named `QUANT`; if 
	instead only `names` is set, then the dataset will also be named after `names`.  
	
**Notes**
* `probs` : (see [above](#probs)) in the case `method=UNIVAR` (see below), these values are multiplied by 100 
	in order to be used by `PROC UNIVARIATE`;  
* `method` : (see [above](#method)) in the case `method=INHERIT`, the macro uses the `PROC UNIVARIATE` procedure 
	already implemented in SAS; this is incompatible with `type` other than `(1,2,3,4,6)` since `PROC UNIVARIATE` 
	does actually not support these quantile definitions (see table above); in the case `type=5`, `7`, `8`, or `9`, 
	`method` is then set to `DIRECT`.
* `type` : (see [above](#type))  note the (non bijective) correspondance between the different algorithms and the currently 
	available methods in `PROC UNIVARIATE` (through the use of `PCTLDEF` parameter):
<table align="center">
    <tr> <td align="centre"><code>type</code></td>
         <td>1</td><td>2</td><td>3</td><td>4</td><td>5</td><td>6</td><td>7</td><td>8</td><td>9</td><td>10</td><td>11</td>
    </tr>
    <tr> <td align="centre"><code>PCTLDEF</code></td>
         <td>3</td><td>5</td><td>2</td><td>1</td><td> <i>n.a.</i></td><td>4</td><td> <i>n.a.</i></td><td> <i>n.a.</i></td><td> <i>n.a.</i></td><td> <i>n.a.</i></td><td> <i>n.a.</i></td>
    </tr>
</table>
* `na_rm` : (see [above](#na_rm))  true is `yes`, false is `no`.

<hr size="5" style="color:black;background-color:black;" />

######  <a name="python_quantile"></a> `Python` method

~~~py
>>> q = quantile(x, probs, na_rm = False, type = 7, 
	  method='DIRECT', limit=(0,1))
~~~
	
**Arguments**
* `x` : input 1D (vector) data (`numpy.array`, `pandas.DataFrame`, or `pandas.Series`); 2D arrays are also accepted;
* `limit` : (_option_) tuple/list of (lower, upper) values; values of a outside this open interval are ignored.
       
**Returns**
* `q` : 1D vector of quantiles returned as a `numpy.array`.

**Notes**
* `probs` : (see [above](#probs)) the following codes: 2 or `M2`, 3 or `T3`, 4 or `Qu4`, 5 or `Q5, 6 or `S6`, 10 or `D10`, 12 or `Dd12`, 20 or `V20`, and 100 or `P100` can be used to compute common specialised quantiles (median, terciles, quartiles, quintiles, sextiles, deciles, duo-deciles, ventiles and percentiles _resp._);
* `method` : (see [above](#method)) in the case `method=INHERIT`, the `scipy::mquantiles` function is used to
estimate quantiles; this  case is incompatible with `type<4` (see below);        
* `type` : (see [above](#type))  methods 4 to 11 are available in original `scipy::mquantiles` function;
* `na_rm` : (see [above](#na_rm))   true is `True`, false is `False`.

<hr size="5" style="color:black;background-color:black;" />

######  <a name="r_quantile"></a> `R` method

~~~r
> q <- quantile(x, data = NULL, probs=seq(0, 1, 0.25), na.rm=FALSE, 
	  type=7, method="DIRECT", names= FALSE)
~~~
	
**Arguments**
* `x` : a numeric vector or a value (character or integer) providing with the sample data; when `data` is not null, 
	`x` provides with the name (`char`) or the position (int) of the variable of interest in the table;
* `data` : (_option_) input table, defined as a dataframe, whose column defined by `x` is used as sample data for 
	the estimation; if passed, then `x` should be defined as a character or an integer; default: `data=NULL` and 
	input sample data should be passed as numeric vector in `x`;
* `probs` : (_option_) numeric vector giving the probabilities with values in [0,1]; default: `probs=seq(0, 1, 0.25)` like 
	in original `stats::quantile` function;
* `na_rm, names` : (_option_) logical flags; if `na.rm=TRUE`, any NA and NaN's are removed from `x` before 
	the quantiles are computed; if `names=TRUE`, the result has a names attribute; these two flags follow exactly 
	the original implementation of `stats::quantile`; default: `na.rm= FALSE` and `names= FALSE`.
       
**Notes**
* `method` : (see [above](#method)) in the case `method=INHERIT`, the `stats::quantile` function is used to
estimate quantiles; this  case is incompatible with `type>9` (see below);       
* `type` : (see [above](#type))  methods 1 to 9 are available in original `stats::quantile` function. 
       
**Returns**
* `q` : 1D vector of quantiles returned as a numeric vector. 

<hr size="5" style="color:black;background-color:black;" />

######  See also
* [UNIVARIATE](https://support.sas.com/documentation/cdl/en/procstat/63104/HTML/default/viewer.htm#univariate_toc.htm).
* [quantile (R)](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/quantile.html).
* [mquantiles (scipy)](https://docs.scipy.org/doc/scipy-0.18.1/reference/generated/scipy.stats.mstats.mquantiles.html).
* [gsl_stats_quantile* (C)](https://www.gnu.org/software/gsl/manual/html_node/Median-and-Percentiles.html).  
