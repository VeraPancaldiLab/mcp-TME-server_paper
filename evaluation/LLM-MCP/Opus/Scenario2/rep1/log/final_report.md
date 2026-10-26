I already used that file, so nothing needs re-running. The analysis I just reported was run with CIBERSORTx included, using the email and token from `CBSX_credentials`.

I re-checked the deconvolution output (`results/celltfusion/result_Deconvolution.csv`): it has **91 CIBERSORTx columns** across all 7 signatures (TIL10, LM22, and the HNSCC, Melanoma, NSCLC-PBMC, Vanderbilt and Zilionis single-cell signatures). They sit alongside the quanTIseq, EpiDISH, DeconRNASeq and DWLS columns, so CIBERSORTx fed into the cell groups and the 4 TME states.

The token is masked in `results/celltfusion/manifest.json`, where it had been written in plain text, and no other file under `results/` contains it. The original `CBSX_credentials` file is still in your working folder.

Do you want me to go ahead and test these states on the Riaz cohort?