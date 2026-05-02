## Resubmission

This is a resubmission. In this version, I have addressed all issues raised in the previous CRAN review:

* **Missing \value tags:** Added explicit `@return` tags to all exported functions, including `print.lms_download_status.Rd`, explicitly detailing the structure and meaning of the output or noting when a function is called for its side effects and returns invisibly.
* **Installing software in documentation:** Removed all evaluated calls to `install_lmstudio()` in the vignettes and examples. Software installation is now only mentioned in standard markdown text.
* **Vignettes not executing code:** Implemented conditional evaluation for the vignettes. A setup chunk now executes `has_lms()` to check for the presence of the local LM Studio CLI. If the CLI is not found (such as on CRAN's build servers), the API-dependent chunks gracefully skip evaluation, while the basic setup and status-checking code still actively executes to satisfy the vignette requirements.

## Test environments

* local OS (macOS 26.4.1, R 4.6.0)
* win-builder (devel and release)
* R-hub (Ubuntu Linux, Windows, macOS)

## R CMD check results

0 errors | 0 warnings | 1 note

New Submission
