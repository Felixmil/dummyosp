#' Report the versions of the imported OSP packages
#'
#' A trivial function whose only purpose is to reference the imported packages,
#' so the dependency install can be verified.
#'
#' @return A named character vector of package versions.
#' @export
ospVersions <- function() {
  c(
    ospsuite = as.character(utils::packageVersion("ospsuite")),
    ospsuite.plots = as.character(utils::packageVersion("ospsuite.plots"))
  )
}
