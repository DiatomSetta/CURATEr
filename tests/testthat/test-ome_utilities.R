# ------------------------------------------------------------------------------
# Test Setup: Create dummy DataFrames to simulate files
# ------------------------------------------------------------------------------
mock_sample <- tibble::tibble(
  samp_name = c("sample1", "sample2"),
  assay_name = c("assayA", "assayB"),
  value = list("10", "20") # Simulating the mixed list columns
)

mock_run <- tibble::tibble(
  samp_name = c("sample1", "sample2"),
  run_id = c("runX", "runY")
)

# ------------------------------------------------------------------------------
#  Tests
# ------------------------------------------------------------------------------
test_that("join_faire_metadata creates output directory if it does not exist", {
  # Create a clean temporary directory structure
  temp_base <- tempfile("here_mock")
  temp_out <- "nested/test/dir"

  # Mock here::here to point inside our temporary sandbox
  mockery::stub(join_faire_metadata, "here::here", function(...) file.path(temp_base, ...))
  mockery::stub(join_faire_metadata, "readr::read_csv", function(path) {
    if (grepl("sample", path)) return(mock_sample) else return(mock_run)
  })

  # Run function (using files that our mocked read_csv handles)
  expect_message(
    join_faire_metadata(
      input_dir = "in",
      sample_metadata = "sample.csv",
      experiment_run_file = "run.csv",
      output_dir = temp_out
    )
  )

  # Assert directory structure was created successfully
  expect_true(dir.exists(file.path(temp_base, temp_out)))
})


test_that("join_faire_metadata local CSV paths read, type convert, and left_join correctly", {
  temp_base <- tempfile()
  dir.create(temp_base)

  # Stub file systems and reading utilities
  mockery::stub(join_faire_metadata, "here::here", function(...) file.path(temp_base, ...))
  mockery::stub(join_faire_metadata, "here::here", function(...) file.path(...))
  mockery::stub(join_faire_metadata, "readr::read_csv", function(path) {
    if (grepl("sample", path)) return(mock_sample) else return(mock_run)
  })

  # Capture the written CSV file to test internal manipulation logic
  mock_write <- mockery::mock()
  mockery::stub(join_faire_metadata, "readr::write_csv", mock_write)

  join_faire_metadata(
    input_dir = "in",
    sample_metadata = "sample.csv",
    experiment_run_file = "run.csv",
    output_dir = "out"
  )

  # Extract the object passed to readr::write_csv
  written_df <- mockery::mock_args(mock_write)[[1]][[1]]

  # Assertions
  expect_s3_class(written_df, "data.frame")
  expect_false("assay_name" %in% colnames(written_df)) # Dropped via select(-"assay_name")
  expect_type(written_df$value, "double")             # Flattened from list & converted to numeric
  expect_equal(nrow(written_df), 2)
})


test_that("join_faire_metadata Google Sheets workflow handles parameters and branches correctly", {
  # Mock googlesheets4::read_sheet behavior
  mock_read_sheet <- mockery::mock(mock_sample, mock_run)
  mockery::stub(join_faire_metadata, "googlesheets4::read_sheet", mock_read_sheet)

  # Mock file writers so it doesn't try to write to actual disk
  mockery::stub(join_faire_metadata, "readr::write_csv", TRUE)
  mockery::stub(join_faire_metadata, "here::here", identity)

  expect_message(
    join_faire_metadata(
      google_doc = TRUE,
      googledoc_url = "https://google.com",
      output_dir = "out"
    )
  )

  # Verify that read_sheet was called exactly twice with correct parameters
  mockery::expect_called(mock_read_sheet, 2)
  expect_equal(mockery::mock_args(mock_read_sheet)[[1]][[2]], "sampleMetadata")
  expect_equal(mockery::mock_args(mock_read_sheet)[[2]][[2]], "experimentRunMetadata")
})


test_that("join_faire_metadata execution fires the terminal user message", {
  # Minimal mock to verify message generation logic works cleanly
  mockery::stub(join_faire_metadata, "readr::read_csv", function(...) mock_sample)
  mockery::stub(join_faire_metadata, "readr::write_csv", TRUE)
  mockery::stub(join_faire_metadata, "here::here", function(...) paste0(...))

  # Fix the 'output_path' error locally in your function first for this to work!
  expect_message(
    join_faire_metadata(input_dir = "in", sample_metadata = "s.csv", experiment_run_file = "r.csv"),
    "Output saved to:"
  )
})


