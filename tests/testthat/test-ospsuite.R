test_that("ospsuite namespace loads", {
  expect_true(requireNamespace("ospsuite", quietly = TRUE))
})

test_that("the Aciclovir example simulation loads", {
  sim_path <- system.file("extdata", "Aciclovir.pkml", package = "ospsuite")
  expect_true(file.exists(sim_path))

  sim <- ospsuite::loadSimulation(sim_path)
  expect_s3_class(sim, "Simulation")
})
