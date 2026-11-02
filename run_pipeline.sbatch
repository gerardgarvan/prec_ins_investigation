#!/bin/bash
#SBATCH --job-name=prec_ins_pipeline
#SBATCH --account=erin.mobley-precision
#SBATCH --qos=erin.mobley-precision
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=128gb
# Adjust --mem based on sacct MaxRSS after a run:
#   sacct -j $SLURM_JOB_ID --format=JobID,MaxRSS,Elapsed
# If MaxRSS > 100 GB raise to 192gb or 256gb.
# If MaxRSS < 60 GB lower to 96gb to free allocation.
#SBATCH --time=08:00:00
#SBATCH --output=logs/pipeline_%j.out
#SBATCH --error=logs/pipeline_%j.err
#SBATCH --mail-type=END,FAIL

module purge
module load R

mkdir -p logs

echo "Job started: $(date)"
echo "Node: $SLURMD_NODENAME"
echo "Memory requested: $SLURM_MEM_PER_NODE MB"

cd "$SLURM_SUBMIT_DIR"

Rscript R/run_all.R

EXIT_CODE=$?
echo "Job finished: $(date) | exit code: $EXIT_CODE"
exit $EXIT_CODE
