#' @include sdf_utils.R
NULL

#' Temporal join
#'
#' Perform left-outer join on 2 `TimeSeriesRDD`s based on inexact timestamp
#' matches
#'
#' @param left The left `TimeSeriesRDD`
#' @param right The right `TimeSeriesRDD`
#' @param tol A character vector specifying a time duration (e.g., "0ns", "5ms",
#'   "5s", "1d", etc) as the tolerance for absolute difference in timestamp values
#'   between each record from `left` and its matching record from `right`.
#'   By default, `tol` is "0ns", which means a record from `left` will only be
#'   matched with a record from `right` if both contain the exact same timestamps.
#' @param direction Specifies the temporal direction of the join, must be one
#'   of ">=", "<=", or "<".
#'   If direction is ">=", then each record from `left` with timestamp `tl`
#'   gets joined with a record from `right` having the largest/most recent
#'   timestamp `tr` such that `tl` >= `tr` and `tl` - `tr` <= `tol` (or
#'   equivalently, 0 <= `tl` - `tr` <= `tol`).
#'   If direction is "<=", then each record from `left` with timestamp `tl`
#'   gets joined with a record from `right` having the smallest/least recent
#'   timestamp `tr` such that `tl` <= `tr` and `tr` - `tl` <= `tol` (or
#'   equivalently, `0 <= `tr` - `tl` <= `tol`).
#'   If direction is "<", then each record from `left` with timestamp `tl`
#'   gets joined with a record from `right` having the smallest/least recent
#'   timestamp `tr` such that `tr` > `tl` and `tr` - `tl` <= `tol` (or
#'   equivalently, 0 < `tr` - `tl` <= `tol`).
#' @param key_columns Columns to be used as the matching key among records from
#'   `left` and `right`: if non-empty, then in addition to matching criteria
#'   imposed by timestamps, a record from `left` will only match one from the
#'   `right` only if they also have equal values in all key columns.
#' @param left_prefix A string to prepend to all columns from `left` after the
#'  join (usually for disambiguation purposes if `left` and `right` contain
#'  overlapping column names).
#' @param right_prefix A string to prepend to all columns from `right` after the
#'  join (usually for disambiguation purposes if `left` and `right` contain
#'  overlapping column names).
#'
#' @examples
#'
#' library(sparklyr)
#' library(sparklyr.flint)
#'
#' sc <- try_spark_connect(master = "local")
#' if (!is.null(sc)) {
#'   ts_1 <- copy_to(sc, tibble::tibble(t = seq(10), u = seq(10))) %>%
#'     from_sdf(is_sorted = TRUE, time_unit = "SECONDS", time_column = "t")
#'   ts_2 <- copy_to(sc, tibble::tibble(t = seq(10) + 1, v = seq(10) + 1L)) %>%
#'     from_sdf(is_sorted = TRUE, time_unit = "SECONDS", time_column = "t")
#'   future_left_join_ts <- asof_join(ts_1, ts_2, tol = "1s", direction = "<=")
#' } else {
#'   message("Unable to establish a Spark connection!")
#' }
#'
#' @family Temporal join functions
#'
#' @export
asof_join <- function(left,
                      right,
                      tol = "0ms",
                      direction = c(">=", "<=", "<"),
                      key_columns = list(),
                      left_prefix = NULL,
                      right_prefix = NULL
) {
  direction <- match.arg(direction)
  key_columns <- as.list(key_columns)
  left <- spark_jobj(left)
  right <- spark_jobj(right)

  do.invoke <- function(ts_rdd_1, method, ts_rdd_2, ...) {
    ts_rdd_1 %>%
      invoke(method, ts_rdd_2, tol, key_columns, left_prefix, right_prefix, ...)
  }
  out <- switch(
    direction,
    `>=` = left %>% do.invoke("leftJoin", right),
    `<=` = left %>% do.invoke("futureLeftJoin", right, FALSE),
    `<` = left %>% do.invoke("futureLeftJoin", right, TRUE)
  )

  out %>% new_ts_rdd()
}

#' Temporal left join
#'
#' Perform left-outer join on 2 `TimeSeriesRDD`s based on inexact timestamp
#' matches, where each record from `left` with timestamp `t` matches the
#' record from `right` having the most recent timestamp at or before `t`.
#' Notice this is equivalent to `asof_join()` with `direction` = "<=".
#' See \code{\link[sparklyr.flint:asof_join]{asof_join}}.
#'
#' @inheritParams asof_join
#'
#' @examples
#'
#' library(sparklyr)
#' library(sparklyr.flint)
#'
#' sc <- try_spark_connect(master = "local")
#' if (!is.null(sc)) {
#'   ts_1 <- copy_to(sc, tibble::tibble(t = seq(10), u = seq(10))) %>%
#'     from_sdf(is_sorted = TRUE, time_unit = "SECONDS", time_column = "t")
#'   ts_2 <- copy_to(sc, tibble::tibble(t = seq(10) + 1, v = seq(10) + 1L)) %>%
#'     from_sdf(is_sorted = TRUE, time_unit = "SECONDS", time_column = "t")
#'   left_join_ts <- asof_left_join(ts_1, ts_2, tol = "1s")
#' } else {
#'   message("Unable to establish a Spark connection!")
#' }
#'
#' @family Temporal join functions
#'
#' @export
asof_left_join <- function(left,
                      right,
                      tol = "0ms",
                      key_columns = list(),
                      left_prefix = NULL,
                      right_prefix = NULL
) {
  asof_join(left = left,
            right = right,
            tol = tol,
            direction = ">=",
            key_columns = key_columns,
            left_prefix = left_prefix,
            right_prefix = right_prefix)
}

#' Temporal future left join
#'
#' Perform left-outer join on 2 `TimeSeriesRDD`s based on inexact timestamp
#' matches, where each record from `left` with timestamp `t` matches the
#' record from `right` having the most recent timestamp at or after `t` if
#' `strict_lookahead` is FALSE (default) or having the most recent timestamp
#' strictly after `t` if `strict_lookahead` is TRUE.
#' Notice this is equivalent to `asof_join()` with `direction` = ">=" if
#' `strict_lookahead` is FALSE (default) or direction `>` if
#' `strict_lookahead` is TRUE.
#' See \code{\link[sparklyr.flint:asof_join]{asof_join}}.
#'
#' @inheritParams asof_join
#' @param strict_lookahead Whether each record from `left` with timestamp `t`
#'   should match record from `right` with the smallest timestamp strictly
#'   greater than `t` (default: FALSE)
#'
#' @examples
#'
#' library(sparklyr)
#' library(sparklyr.flint)
#'
#' sc <- try_spark_connect(master = "local")
#' if (!is.null(sc)) {
#'   ts_1 <- copy_to(sc, tibble::tibble(t = seq(10), u = seq(10))) %>%
#'     from_sdf(is_sorted = TRUE, time_unit = "SECONDS", time_column = "t")
#'   ts_2 <- copy_to(sc, tibble::tibble(t = seq(10) + 1, v = seq(10) + 1L)) %>%
#'     from_sdf(is_sorted = TRUE, time_unit = "SECONDS", time_column = "t")
#'   future_left_join_ts <- asof_future_left_join(ts_1, ts_2, tol = "1s")
#' } else {
#'   message("Unable to establish a Spark connection!")
#' }
#'
#' @family Temporal join functions
#'
#' @export
asof_future_left_join <- function(left,
                      right,
                      tol = "0ms",
                      key_columns = list(),
                      left_prefix = NULL,
                      right_prefix = NULL,
                      strict_lookahead = FALSE
) {
  asof_join(left = left,
            right = right,
            tol = tol,
            direction = if (strict_lookahead) "<" else "<=",
            key_columns = key_columns,
            left_prefix = left_prefix,
            right_prefix = right_prefix)
}
