#!/bin/bash

# Example sbatch script

srun -N 4 bash -c 'echo Hello, world from $(hostname)!'
sleep 10
