rscript_output <- function(testfile) {
    rscrpt <- paste0(R.home("bin"), "/Rscript")
    system2(
        command = rscrpt,
        args = paste0("'", testthat::test_path(sprintf("fixtures/%s", testfile)), "'"),
        stdout = TRUE,
        stderr = TRUE
    )
}

test_that("as_reader output functions non-interactively", {
    terminal_output <- rscript_output("1-as_reader.R")
    expected_string <- c("[1] 1", "[1] 2", "[1] 3", "[1] 4", "[1] 5", "[1] 6", "[1] 7", "[1] 8", "[1] 9", "[1] 10")
    expect_identical(terminal_output, expected_string)
})


test_that("transform output functions non-interactively", {
    terminal_output <- rscript_output("2-transform.R")
    expected_string <- c("[1] 5", "[1] 5", "[1] 5", "[1] 5", "[1] 5")
    expect_identical(terminal_output, expected_string)
})
