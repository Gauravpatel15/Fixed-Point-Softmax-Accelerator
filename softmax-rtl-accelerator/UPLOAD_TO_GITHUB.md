# Upload this project to GitHub

1. Extract the ZIP locally.
2. Create a new GitHub repository, for example `softmax-rtl-accelerator`.
3. Leave GitHub's automatic README, .gitignore and license options empty; this bundle
   already supplies the README and .gitignore. Choose a license separately if desired.
4. Choose **uploading an existing file** (or **Add file -> Upload files**).
5. Upload the CONTENTS of the extracted `softmax-rtl-accelerator` folder: `README.md`
   and the `rtl`, `sim`, `scripts`, `vivado`, `constraints`, and `docs` folders.
   Include `.gitignore` and `.gitattributes` (show hidden files if needed).
6. Commit with message `Initial release: verified fixed-point Softmax RTL accelerator`.

Upload extracted files, not just the ZIP, so GitHub renders the README and lets
recruiters inspect the RTL. Do not upload the working Vivado build directory,
checkpoints, backup files, or unsanitized local logs.

Suggested description:
> Fixed-point Softmax RTL accelerator with Horner/Estrin evaluation, BRAM buffering,
> 16K-entry rows, Python reference verification, and Vivado implementation results.

Suggested topics: `systemverilog`, `fpga`, `vivado`, `rtl`, `softmax`, `fixed-point`.

This bundle does not select a software license on your behalf. AMD XPM libraries
are external dependencies supplied with Vivado, not included source files.
