# Input Data

This folder contains the three input instances used by the GreenGrid Energy procurement model.

| File | Purpose |
|---|---|
| `small_data.csv` | Small optimisation instance |
| `medium_data.csv` | Medium optimisation instance |
| `large_data.csv` | Large optimisation instance |

## Data Structure

The R parser expects the files to contain rows in this order:

1. Electricity demand by delivery period
2. Supplier concentration limits
3. Alliance concentration limits
4. Minimum supplier commitments
5. Supplier alliance membership rows
6. Supplier prices across delivery periods

The parser reads these rows positionally rather than using named CSV columns. Preserve the original row order and numeric structure when using the files.

## Usage

The R script reads these files from `data/`. Run it from the repository root, or update the file paths if running from another working directory.

These datasets are assignment-provided inputs for the optimisation exercise.
