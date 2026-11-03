#' @title OME Data Processing Utilities
#' @description A collection of utilities for the
#' [Ocean Molecular Ecology (OME) group](https://www.pmel.noaa.gov/ocean-molecular-ecology/)
#' to read in data and format for decontamination.
#' @name ome_utilities
NULL

#' Load and merge faire metdata
#'
#' @description
#' Load faire data from faire sample Metadata and experiment run metadata files
#' or google doc sheet for OME lab. This should work with all metadata generated
#' using fair eDNA standards [FAIR eDNA](https://fair-edna.github.io/guidelines.html).
#'
#'
#' @param input_dir character string of the directory found within `here()` where the
#' downloaded faire metadata files are stored (default is NULL).
#' @param experiment_run_file character string of file name for faire experiment
#' run metadata (default is NULL).
#' @param sample_metadata character string of file name for faire experiment run
#' metadata (default is NULL).
#' @param google_doc Boolean TRUE or FALSE, if TRUE, google doc metadata will
#' be read in, if false `input_dir`, `experiment_run_file`, and `sample_metadata`
#' will be used to merge data (default is FALSE).
#' @param googledoc_url character string of google doc url where faire metadata
#' is stored (default is NULL).
#' @param output_dir character string of the directory found within `here()` where the
#' merged `metadata_file_name` will be stored (default is "data/decontamination").
#' @param metadata_file_name character string of the name of the merged metadata
#' (default naming is "Metadata_faire.csv")
#'
#' @returns A csv file of merged faire metadata (`metadata_file_name`) within
#' output directory (`output_dir`).
#' @export
#'
#' @examples
#' ## If pulling from google spreadsheet:
#' join_faire_metadata(google_doc = TRUE,
#'                     googledoc_url = "https://docs.google.com/spreadsheets/example",
#'                     output_dir = "data/decontamination")
#' ## If pulling from downloaded faire sample metadata:
#' join_faire_metadata(input_dir = "data/raw",
#'                     sample_metadata = "sampleMetadata_faire.csv",
#'                     experiment_run_file = "experimentRunMetadata_faire.csv",
#'                     output_dir = "data/decontamination")
#'
join_faire_metadata <- function(input_dir = NULL,
                                sample_metadata = NULL,
                                experiment_run_file = NULL,
                                google_doc = FALSE,
                                googledoc_url = NULL,
                                output_dir = "data/decontamination",
                                metadata_file_name = "Metadata_faire.csv") {
  # make sure output_dir exists, and if it doesn't make one:
  if (!dir.exists(here::here(output_dir))) {
    dir.create(here::here(output_dir), recursive = TRUE)
  }

  # if google doc with faire data:
  if (google_doc == TRUE) {

  # Read in each sheet
  sample_metadata <- googlesheets4::read_sheet(googledoc_url, sheet = "sampleMetadata")
  experiment_run_metadata <- googlesheets4::read_sheet(googledoc_url, sheet = "experimentRunMetadata")
  } else {

  # read in downloaded faire metadata
  sample_metadata <- readr::read_csv(here::here(input_dir,sample_metadata))
  experiment_run_metadata <- readr::read_csv(here::here(input_dir,experiment_run_file))
  }

  # convert columns that have mixed data types and read in as a list:by
  sample_metadata <- sample_metadata |>
    # Force every list column into a basic character column
    dplyr::mutate(dplyr::across(dplyr::where(is.list),
                                ~ purrr::map_chr(.x, as.character))) |>
    # Automatically guess and apply the correct data types (e.g., numeric)
    readr::type_convert()

  experiment_run_metadata <- experiment_run_metadata |>
    # Force every list column into a basic character column
    dplyr::mutate(dplyr::across(dplyr::where(is.list),
                                ~ purrr::map_chr(.x, as.character))) |>
    # Automatically guess and apply the correct data types (e.g., numeric)
    readr::type_convert()

  # combine metadata
  metadata_file <- experiment_run_metadata |>
    dplyr::left_join(sample_metadata |> dplyr::select(-c("assay_name")), by="samp_name")

  # save combined file:
  readr::write_csv(metadata_file,
                   here::here(output_dir, metadata_file_name))

  # message of where files will be saved to
  message("Output saved to: ", here::here(output_dir))
}

