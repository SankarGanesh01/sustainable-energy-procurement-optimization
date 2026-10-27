library(ompr)
library(ompr.roi)
library(ROI)
library(ROI.plugin.highs)
library(ROI.plugin.glpk)
library(dplyr)

# Function to parse the GreenGrid CSV files based on specified row structure
parse_greengrid_data <- function(file_path) {
  raw_lines <- readLines(file_path)
  raw_split <- strsplit(raw_lines, ",")
  
  demand          <- as.numeric(raw_split[[1]])
  supplier_limits <- as.numeric(raw_split[[2]])
  alliance_limits <- as.numeric(raw_split[[3]])
  min_commitments <- as.numeric(raw_split[[4]])
  
  n_periods   <- length(demand)
  n_suppliers <- length(min_commitments)
  
  # Calculate number of alliance rows based on file length
  n_alliances <- length(raw_split) - 4 - n_suppliers
  
  if (n_alliances < 0) {
    stop("Dataset structure does not match expected format")
  }
  
  alliances <- list()
  if (n_alliances > 0) {
    for (i in 1:n_alliances) {
      alliances[[i]] <- as.numeric(raw_split[[4 + i]])
    }
  }
  
  # Price matrix starts after alliances
  price_start <- 5 + n_alliances
  price_matrix <- matrix(
    as.numeric(unlist(raw_split[price_start:length(raw_split)])),
    nrow = n_suppliers,
    byrow = TRUE
  )
  
  list(
    D = demand, SL = supplier_limits, AL = alliance_limits,
    MC = min_commitments, alliances = alliances, P = price_matrix,
    n_S = n_suppliers, n_T = n_periods, n_A = n_alliances
  )
}

# MILP model formulation
build_model <- function(data, relax = FALSE) {
  var_type <- if (relax) "continuous" else "binary"
  
  model <- MIPModel() %>%
    # x is energy amount, y is supplier selection
    add_variable(x[i, t], i = 1:data$n_S, t = 1:data$n_T, lb = 0) %>%
    add_variable(y[i], i = 1:data$n_S, type = var_type, lb = 0, ub = 1) %>%
    
    set_objective(
      sum_expr(data$P[i, t] * x[i, t], i = 1:data$n_S, t = 1:data$n_T),
      "min"
    ) %>%
    
    # Meet demand for every period
    add_constraint(
      sum_expr(x[i, t], i = 1:data$n_S) == data$D[t],
      t = 1:data$n_T
    ) %>%
    
    # Supplier-specific capacity cap
    add_constraint(
      x[i, t] <= data$SL[t] * data$D[t],
      i = 1:data$n_S, t = 1:data$n_T
    ) %>%
    
    # Total volume must meet minimum commitment if supplier is picked
    add_constraint(
      sum_expr(x[i, t], t = 1:data$n_T) >= data$MC[i] * y[i],
      i = 1:data$n_S
    ) %>%
    
    # Linking x to y using tight Big-M logic
    add_constraint(
      x[i, t] <= (data$SL[t] * data$D[t]) * y[i],
      i = 1:data$n_S, t = 1:data$n_T
    )
  
  # Dynamic handling of alliance constraints
  if (data$n_A > 0) {
    for (a in 1:data$n_A) {
      members <- data$alliances[[a]]
      model <- model %>%
        add_constraint(
          sum_expr(x[i, t], i = members) <= data$AL[t] * data$D[t],
          t = 1:data$n_T
        )
    }
  }
  
  return(model)
}

# Execute solver with specific 3600s time limits
solve_procurement <- function(model, solver_name) {
  start_time <- Sys.time()
  # NOTE: Debugging support (ChatGPT, 10 April 2026) was used here to
  # correctly implement solver time limits and handle solver outputs.
  result <- solve_model(
    model,
    with_ROI(
      solver = solver_name,
      control = if (solver_name == "highs") {
        list(time_limit = 3600, output_flag = TRUE)
      } else {
        # Multiply by 1000 because GLPK uses milliseconds
        list(tm_limit = 3600 * 1000, verbose = TRUE) 
      }
    )
  )
  
  end_time <- Sys.time()
  runtime <- as.numeric(difftime(end_time, start_time, units = "secs"))
  status  <- result$status
  
  # Capture NA if solver fails to find a solution
  if (!(status %in% c("optimal", "success", "feasible"))) {
    obj_val <- NA
  } else {
    obj_val <- objective_value(result)
  }
  
  cat("\nSolver:", solver_name,
      "\nStatus:", status,
      "\nObjective:", ifelse(is.na(obj_val), "NA", round(obj_val, 2)),
      "\nRuntime:", round(runtime, 2), "seconds\n")
  
  list(obj = obj_val, time = runtime, status = status)
}

# Execution block
datasets <- c("small_data.csv", "medium_data.csv", "large_data.csv")
results_list <- list()

sink("solver_logs.txt", split = TRUE)

for (ds in datasets) {
  cat("\nProcessing Dataset:", ds, "\n")
  data_parsed <- parse_greengrid_data(ds)
  
  milp_model <- build_model(data_parsed, relax = FALSE)
  lp_model   <- build_model(data_parsed, relax = TRUE)
  
  # Running both MILP solvers and LP relaxation
  highs_res <- solve_procurement(milp_model, "highs")
  glpk_res  <- solve_procurement(milp_model, "glpk")
  lp_res    <- solve_procurement(lp_model, "highs")
  
  # Calculate integrality gap
  gap <- if (!is.na(highs_res$obj) && !is.na(lp_res$obj)) {
    ((highs_res$obj - lp_res$obj) / highs_res$obj) * 100
  } else {
    NA
  }
  
  results_list[[ds]] <- data.frame(
    Dataset = ds,
    MILP_Obj_HiGHS = ifelse(is.na(highs_res$obj),NA, round(highs_res$obj, 2)),
    Runtime_HiGHS = round(highs_res$time, 2),
    MILP_Obj_GLPK = ifelse(is.na(glpk_res$obj), NA, round(glpk_res$obj, 2)),
    Runtime_GLPK = round(glpk_res$time, 2),
    LP_Relaxation = ifelse(is.na(lp_res$obj), NA, round(lp_res$obj, 2)),
    Integrality_Gap_Percent = ifelse(is.na(gap), NA, round(gap, 4))
  )
}

sink()

# Display summary and save files
final_results <- bind_rows(results_list)
print(final_results)
write.csv(final_results, "Procurement_Results_Table.csv", row.names = FALSE)

# Append session info for submission documentation
sink("solver_logs.txt", append = TRUE)
print(sessionInfo())
sink()


#PART-D

library(ompr)
library(ompr.roi)
library(ROI)
library(ROI.plugin.highs)
library(ROI.plugin.glpk)
library(dplyr)

# 1. DATA PARSING FUNCTION
parse_greengrid_data <- function(file_path) {
  raw_lines <- readLines(file_path)
  raw_split <- strsplit(raw_lines, ",")
  demand <- as.numeric(raw_split[[1]])
  supplier_limits <- as.numeric(raw_split[[2]])
  alliance_limits <- as.numeric(raw_split[[3]])
  min_commitments <- as.numeric(raw_split[[4]])
  n_S <- length(min_commitments)
  n_T <- length(demand)
  n_A <- length(raw_split) - 4 - n_S
  alliances <- list()
  if (n_A > 0) {
    for (i in 1:n_A) alliances[[i]] <- as.numeric(raw_split[[4 + i]])
  }
  price_matrix <- matrix(as.numeric(unlist(raw_split[(5 + n_A):length(raw_split)])),
                         nrow = n_S, byrow = TRUE)
  list(D = demand, SL = supplier_limits, AL = alliance_limits, MC = min_commitments, 
       alliances = alliances, P = price_matrix, n_S = n_S, n_T = n_T, n_A = n_A)
}

# 2. MODIFIED MODEL FUNCTION 
build_model_fairness <- function(data, relax = FALSE) {
  var_type <- if (relax) "continuous" else "binary"
  M_fair <- max(data$P) # Big-M constant for price logic
  
  model <- MIPModel() %>%
    # Decision Variables
    add_variable(x[i, t], i = 1:data$n_S, t = 1:data$n_T, lb = 0) %>%
    add_variable(y[i], i = 1:data$n_S, type = var_type, lb = 0, ub = 1) %>%
    # New continuous variable for the minimum selected price per period
    add_variable(p_min[t], t = 1:data$n_T, lb = 0) %>%
    
    set_objective(sum_expr(data$P[i, t] * x[i, t], i = 1:data$n_S, t = 1:data$n_T), "min") %>%
    
    # Baseline Constraints
    add_constraint(sum_expr(x[i, t], i = 1:data$n_S) == data$D[t], t = 1:data$n_T) %>%
    add_constraint(x[i, t] <= data$SL[t] * data$D[t], i = 1:data$n_S, t = 1:data$n_T) %>%
    add_constraint(sum_expr(x[i, t], t = 1:data$n_T) >= data$MC[i] * y[i], i = 1:data$n_S) %>%
    add_constraint(x[i, t] <= (data$SL[t] * data$D[t]) * y[i], i = 1:data$n_S, t = 1:data$n_T)
  
  # Alliance Constraints
  if (data$n_A > 0) {
    for (a in 1:data$n_A) {
      members <- data$alliances[[a]]
      model <- model %>% add_constraint(sum_expr(x[i, t], i = members) <= data$AL[t] * data$D[t], t = 1:data$n_T)
    }
  }
  
  #Fairness Constraints (Linearized)
  model <- model %>%
    # Define p_min as the lower bound of selected supplier prices
    add_constraint(p_min[t] <= data$P[i, t] + M_fair * (1 - y[i]), 
                   i = 1:data$n_S, t = 1:data$n_T) %>%
    # AI-assisted clarification (ChatGPT, 10 April 2026):
    # Used to correct formulation from supplier-level constraint to total cost constraint
    # Cap selected prices at 120% of p_min
    add_constraint(
      sum_expr(data$P[i, t] * x[i, t], i = 1:data$n_S) <= 1.2 * p_min[t] * data$D[t],
      t = 1:data$n_T
    )
  return(model)
}

# 3. SOLVER FUNCTION (Strict 3600s Limit)
solve_procurement <- function(model, solver_name) {
  start_time <- Sys.time()
  # Control handles both seconds (HiGHS) and milliseconds (GLPK)
  result <- solve_model(model, with_ROI(solver = solver_name, 
                                        control = if(solver_name == "highs") list(time_limit = 3600, output_flag = TRUE) 
                                        else list(tm_limit = 3600 * 1000, verbose = TRUE)))
  
  runtime <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  obj_val <- if (result$status %in% c("optimal", "success", "feasible")) objective_value(result) else NA
  list(obj = obj_val, time = runtime)
}

# 4. EXECUTION BLOCK FOR PART D
datasets <- c("small_data.csv", "medium_data.csv", "large_data.csv")
results_d <- list()

sink("solver_logs_PartD.txt", split = TRUE)

for (ds in datasets) {
  cat("\n--- MODIFIED MODEL (PART D):", ds, "---\n")
  data <- parse_greengrid_data(ds)
  
  # 1. Solve Modified MILP with HiGHS
  cat("Running HiGHS MILP...\n")
  h_res <- solve_procurement(build_model_fairness(data), "highs")
  
  # 2. Solve Modified MILP with GLPK
  cat("Running GLPK MILP...\n")
  g_res <- solve_procurement(build_model_fairness(data), "glpk")
  
  # 3. Solve LP Relaxation of Modified Model
  cat("Running LP Relaxation...\n")
  l_res <- solve_procurement(build_model_fairness(data, relax = TRUE), "highs")
  
  # Store and Round Results
  results_d[[ds]] <- data.frame(
    Dataset = ds,
    Fair_MILP_HiGHS = ifelse(is.na(h_res$obj), NA, round(h_res$obj, 2)),
    Fair_MILP_GLPK = ifelse(is.na(g_res$obj), NA, round(g_res$obj, 2)),
    Fair_LP_Relaxation = ifelse(is.na(l_res$obj), NA, round(l_res$obj, 2)),
    Fair_Gap_Pct = ifelse(is.na(h_res$obj) | is.na(l_res$obj), NA, 
                          round(((h_res$obj - l_res$obj)/h_res$obj)*100, 4))
  )
}

sink()

# 5. FINAL TABLE AND SESSION INFO
final_d_table <- bind_rows(results_d)
print(final_d_table)
write.csv(final_d_table, "Modified_Results_PartD.csv", row.names = FALSE)

sink("solver_logs_PartD.txt", append = TRUE)
cat("\n\n--- PART D SESSION INFO ---\n")
print(sessionInfo())
sink()