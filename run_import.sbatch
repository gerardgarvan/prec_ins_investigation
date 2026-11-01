#!/bin/bash
# Run the import step as a batch job with enough memory.
# Submit FROM THE PROJECT ROOT (the folder containing R/):
#   mkdir -p logs && sbatch run_import.sbatch
# After it finishes, check peak memory:
#   sacct -j <jobid> --format=JobID,State,Elapsed,ReqMem,MaxRSS
#
#SBATCH --job-name=pcs_import
#SBATCH --account=erin.mobley-precision
#SBATCH --qos=erin.mobley-precision
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=128gb
#SBATCH --time=08:00:00
#SBATCH --output=logs/import_%j.log

module purge
module load R

cd "$SLURM_SUBMIT_DIR"

Rscript -e 'source("R/01_import.R")'
