# Results

This folder contains the saved outputs from the procurement optimisation experiments.

| File | Description |
|---|---|
| `Procurement_Results_Table.csv` | Summary of baseline solver results, including objective values, runtimes, LP relaxation values, and integrality-gap calculations where available. |

The R script also generates `Modified_Results_PartD.csv` for the pricing-fairness model and solver log files for the experiments. Add the Part D results file here once it has been generated and checked.

Solver status matters when interpreting the results. An objective value should only be treated as a feasible solution when the solver has returned an appropriate status; a time limit alone does not prove infeasibility or optimality.
