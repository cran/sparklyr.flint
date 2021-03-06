% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/summarizers.R
\name{summarize_weighted_covar}
\alias{summarize_weighted_covar}
\title{Weighted covariance summarizer}
\usage{
summarize_weighted_covar(
  ts_rdd,
  xcolumn,
  ycolumn,
  weight_column,
  window = NULL,
  key_columns = list()
)
}
\arguments{
\item{ts_rdd}{Timeseries RDD being summarized}

\item{xcolumn}{Column representing the first random variable}

\item{ycolumn}{Column representing the second random variable}

\item{weight_column}{Column specifying relative weight of each data point}

\item{window}{Either an R expression specifying time windows to be summarized
(e.g., `in_past("1h")` to summarize data from looking behind 1 hour at
each time point, `in_future("5s")` to summarize data from looking forward
5 seconds at each time point), or `NULL` to compute aggregate statistics
on records grouped by timestamps}

\item{key_columns}{Optional list of columns that will form an equivalence
relation associating each record with the time series it belongs to (i.e.,
any 2 records having equal values in those columns will be associated with
the same time series, and any 2 records having differing values in those
columns are considered to be from 2 separate time series and will therefore
be summarized separately)
By default, `key_colums` is empty and all records are considered to be part
of a single time series.}
}
\value{
A TimeSeriesRDD containing the summarized result
}
\description{
Compute unbiased weighted covariance between values from `xcolumn` and
`ycolumn` within each time window or within each group of records with identical
timestamps, using values from `weight_column` as relative weights, and store
results in a new column named
`<xcolumn>_<ycolumn>_<weight_column>_weightedCovariance`
}
\examples{

library(sparklyr)
library(sparklyr.flint)

sc <- try_spark_connect(master = "local")

if (!is.null(sc)) {
  sdf <- copy_to(sc, tibble::tibble(t = seq(10), u = rnorm(10), v = rnorm(10), w = 1.1^seq(10)))
  ts <- fromSDF(sdf, is_sorted = TRUE, time_unit = "SECONDS", time_column = "t")
  ts_weighted_covar <- summarize_weighted_covar(
    ts,
    xcolumn = "u", ycolumn = "v", weight_column = "w", window = in_past("3s")
  )
} else {
  message("Unable to establish a Spark connection!")
}

}
\seealso{
Other summarizers: 
\code{\link{ols_regression}()},
\code{\link{summarize_avg}()},
\code{\link{summarize_corr2}()},
\code{\link{summarize_corr}()},
\code{\link{summarize_count}()},
\code{\link{summarize_covar}()},
\code{\link{summarize_dot_product}()},
\code{\link{summarize_ema_half_life}()},
\code{\link{summarize_ewma}()},
\code{\link{summarize_geometric_mean}()},
\code{\link{summarize_kurtosis}()},
\code{\link{summarize_max}()},
\code{\link{summarize_min}()},
\code{\link{summarize_nth_central_moment}()},
\code{\link{summarize_nth_moment}()},
\code{\link{summarize_product}()},
\code{\link{summarize_quantile}()},
\code{\link{summarize_skewness}()},
\code{\link{summarize_stddev}()},
\code{\link{summarize_sum}()},
\code{\link{summarize_var}()},
\code{\link{summarize_weighted_avg}()},
\code{\link{summarize_weighted_corr}()},
\code{\link{summarize_z_score}()}
}
\concept{summarizers}
