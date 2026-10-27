# Sustainable Energy Procurement Optimization

## Overview

This project develops a Mixed Integer Linear Programming (MILP) model for GreenGrid Energy, a fictional utility seeking to minimise electricity procurement costs while meeting demand and managing supplier concentration, alliance exposure, and minimum contractual commitments.

The model is implemented in R using `ompr` and the ROI solver interface. It compares HiGHS and GLPK across small, medium, and large datasets and extends the baseline model with a 120% pricing-fairness constraint.

## Objectives

- Minimise total electricity procurement cost across delivery periods.
- Meet demand in every period.
- Enforce supplier-level and supplier-alliance concentration limits.
- Apply minimum total allocation commitments to selected suppliers.
- Compare solver runtimes and solution status as problem size increases.
- Evaluate the computational impact of the pricing-fairness extension.

## Methodology

The model uses two decision-variable types:

- **Continuous variables:** electricity quantity procured from each supplier in each period.
- **Binary variables:** whether a supplier is selected.

The objective minimises the sum of supplier prices multiplied by allocated electricity quantities. Constraints enforce demand satisfaction, supplier and alliance limits, minimum commitments, and linking between supplier selection and procurement quantities.

The extended model introduces a period-specific minimum selected supplier price and constrains total procurement cost to no more than 120% of the cost of meeting demand at that price.

## Solver Comparison

The report compares HiGHS and GLPK under a stated 3,600-second time limit. It reports that the baseline model becomes more computationally demanding as dataset size increases, and that the pricing-fairness extension is particularly challenging on the large instance.

See the report and results files for the recorded outcomes. Solver status, objective values, and runtimes should be interpreted together; a timeout is not proof that a model is infeasible or that an optimum has been found.

## Repository Structure

```text
.
├── README.md
├── .gitignore
├── R/
│   └── sustainable_energy_procurement.R
├── data/
│   ├── README.md
│   ├── small_data.csv
│   ├── medium_data.csv
│   └── large_data.csv
├── results/
│   ├── README.md
│   └── Procurement_Results_Table.csv
└── report/
    └── Sustainable_Energy_Procurement_Report.pdf
```

## Requirements

R and the following packages are used by the script:

- `ompr`
- `ompr.roi`
- `ROI`
- `ROI.plugin.highs`
- `ROI.plugin.glpk`
- `dplyr`

The HiGHS and GLPK solver plugins must be installed and working in the local R environment.

## Running the Model

1. Clone or download the repository.
2. Open the project in R or RStudio.
3. Install the required packages.
4. Ensure the three CSV files are in `data/`.
5. Run `R/sustainable_energy_procurement.R` from the repository root.

The script must use the `data/` paths for all three datasets. It writes solver logs and result CSV files to the current working directory.

The full experiments can take a long time, especially on the large dataset. The script uses a 3,600-second solver time limit for each solve.

## Limitations

- Runtime and solver outcomes depend on the machine, solver version, and configuration.
- A solver timeout does not establish infeasibility or optimality.
- The pricing-fairness extension changes the feasible region and can make larger instances harder to solve.
- The results represent an academic optimisation exercise, not a live electricity procurement system.

## Report

The accompanying PDF documents the MILP formulation, baseline solver comparison, managerial interpretation, and pricing-fairness extension.

## Disclaimer

This is an academic decision-support project. GreenGrid Energy is the scenario used in the assignment; the results should not be interpreted as operational advice for an actual utility.
