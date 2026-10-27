# Scalable Gradient-Based Inference of Pathogen Spread with the Structured Coalescent

This repository contains the supplementary materials for the paper *"Scalable gradient-based inference of pathogen spread with the structured coalescent"*. It provides the BEAST X analysis files for the gradient benchmarks, the sampling-efficiency comparison, the parallel-scaling experiment and a joint phylogeographic analysis of global influenza A/H3N2, built around the adjoint (reverse-mode) gradient of the **structured coalescent approximation (SCA)** as implemented in BEAST X and the BEAGLE library. The random-walk and finite-difference baselines are included for comparison. The gradient builds on the SCA likelihood of [Shao et al. 2026](https://www.pnas.org/doi/abs/10.1073/pnas.2602412123) and returns the derivatives with respect to every migration rate and effective population size in one reverse pass, on multi-core CPUs and NVIDIA GPUs.

## Project Structure

### Analysis Directory (`./XML/analysis/`)

Joint Bayesian phylogeographic analysis of global influenza A/H3N2 (1,529 hemagglutinin sequences sampled from late 2001 to the end of 2006, 14 air-travel communities; Lemey et al. 2014). The genealogy, an HKY substitution model, a strict molecular clock and the SCA migration model are sampled jointly:

- `RE/airCommunities_H3N2_RE.xml` — log-linear migration model with one covariate (the standardized log number of airline seats between two communities) and one random effect for each of the 182 ordered pairs of communities, under a Bayesian bridge prior (Magee et al. 2024). Hamiltonian Monte Carlo updates the random effects with the adjoint gradient.
- `FIX/airCommunities_H3N2_FIX.xml` — the same model with the random effects fixed to zero.

### Benchmark Directory (`./XML/benchmark/`)

Benchmark XMLs that fix the genealogy and update only the migration rates and a single shared effective population size, isolating the SCA likelihood and gradient:

- `gradient/` — L-BFGS optimization of the log-likelihood (of the log-posterior, with log-normal priors on the migration rates, for PEDV and EBOV) with the adjoint gradient and with central finite differences:
  - `denv1_compare.xml` — dengue virus serotype 1, DENV-1 (287 taxa, 10 states; Nunes et al. 2014)
  - `pedv_compare.xml` — porcine epidemic diarrhea virus, PEDV (769 taxa, 26 states; He et al. 2022)
  - `ebov_adjoint.xml` and `ebov_numeric.xml` — Ebola virus, EBOV Makona (1,610 taxa, 56 states; Dudas et al. 2017), with the adjoint and the finite-difference optimizations in separate files
- `sampling/HMC/` and `sampling/RWMH/` — Hamiltonian Monte Carlo and random-walk Metropolis–Hastings chains on the same three datasets (`denv1_*`, `pedv_*`, `ebov_*`) for the effective-sample-size comparison.
- `scaling/` — 25 simulated datasets `const_K<KKK>_n<NNNN>_basta.xml` (e.g. `const_K010_n0250_basta.xml`) on a 5 × 5 grid of 250, 500, 1,000, 1,500 and 2,000 tips by 10, 20, 40, 80 and 120 demes. All cells are prunings of one ReMASTER genealogy over 120 demes (Vaughan 2024), with demes merged for the coarser grids.
- `benchmark_all.sh` — master script that runs every gradient and scaling XML under the CPU thread counts and the GPU setting of the parallel-scaling experiment, then extracts the average likelihood and gradient times printed by the benchmarking build (see below).

## Prerequisites

This benchmarking suite requires:

- Java Runtime Environment (JRE) for BEAST X execution
- BEAST X built from the `basta_adjoint` branch (plus the optional benchmarking build if you want to reproduce the per-call timings; see below)
- BEAGLE library built from the `basta_adjoint` branch with SCA, OpenMP and CUDA support
- NVIDIA CUDA Toolkit to build and run the CUDA backend
- A CUDA-capable NVIDIA GPU for the GPU runs
- A multi-core CPU and an OpenMP-capable compiler (GCC, Clang or Intel) for the CPU runs

## Hardware Used in the Paper

- **Sampling benchmark and parallel-scaling experiment:** cluster node with one NVIDIA H100 GPU (80 GB HBM3), a 26-core (52-thread) Intel Xeon Platinum 8481C CPU at 2.70 GHz and 460 GB of host memory, CUDA 12.4.
- **Gradient accuracy and timing microbenchmarks:** workstation with one NVIDIA GeForce RTX 5090 GPU (32 GB GDDR7), a 16-core (32-thread) AMD Ryzen 9 9950X CPU and 64 GB of host memory, CUDA 13.1.

## Installation

### BEAGLE Library with SCA, OpenMP and GPU Support

The SCA likelihood and adjoint gradient kernels live on the `basta_adjoint` branch. Build BEAGLE with SCA, OpenMP and CUDA enabled:

```bash
git clone -b basta_adjoint https://github.com/beagle-dev/beagle-lib.git
cd beagle-lib/
mkdir build && cd build/
cmake -DBUILD_BIT=ON \
      -DBUILD_OPENMP=ON \
      -DBUILD_CUDA=ON \
      -DCMAKE_INSTALL_PREFIX=$HOME/local ..
make && make install
```

**Important cmake flags:**

- `-DBUILD_BIT=ON` — Enables the SCA likelihood and its adjoint gradient (off by default)
- `-DBUILD_OPENMP=ON` — Enables OpenMP threading for the multi-threaded CPU runs (off by default)
- `-DBUILD_CUDA=ON` — Enables the CUDA backend with the GPU likelihood and gradient kernels

After installation, ensure that the BEAGLE shared libraries are visible to the JVM, e.g.:

```bash
export LD_LIBRARY_PATH=$HOME/local/lib:$LD_LIBRARY_PATH
```

### BEAST X Installation with the SCA Adjoint Gradient

The corresponding BEAST X branch is also `basta_adjoint`:

```bash
git clone -b basta_adjoint https://github.com/beast-dev/beast-mcmc.git
cd beast-mcmc/
ant
```

In `./XML/benchmark/benchmark_all.sh`, set `BEAST_JAR` to point at `beast-mcmc/build/dist/beast.jar` and `BEAGLE_LIB` to the BEAGLE library directory (e.g. `$HOME/local/lib`), so that the JVM finds the library.

#### Optional: Benchmarking Build

To reproduce the per-call timings of the parallel-scaling experiment (parsed by `benchmark_all.sh`), enable the timing output of BEAST X before running `ant`. In `src/dr/evomodel/coalescent/basta/AdjointGenericBastaLikelihoodDelegate.java`:

- set `printTime = true`, so that BEAST X prints the average time per likelihood call and per gradient call, with the backward pass and the eigenbasis transform reported separately;
- lower `ADJ_BENCHMARK_INTERVAL` (1,000,000 by default) below the number of gradient calls in a run, because the averages are printed once every `ADJ_BENCHMARK_INTERVAL` calls.

These averages are cumulative from the first call. The per-gradient times of the gradient benchmark need no special build: each optimization in the `gradient/` XMLs ends with a report that gives the time per gradient, with and without the first (warm-up) call.

> **Keep `printTime = false` for production runs.** With a lowered `ADJ_BENCHMARK_INTERVAL`, BEAST X writes timing lines to the screen throughout the run.

## Running Benchmarks

### Complete Benchmark Suite

```bash
cd XML/benchmark/
./benchmark_all.sh
```

The script runs every XML in `gradient/` and `scaling/` under each entry of `THREAD_COUNTS=(1 4 12 26 32 999)`, where `999` is a sentinel that selects the GPU configuration, `1` runs without threading and any other value selects an OpenMP thread count. The screen and timing output of each run is captured in `results/<xml>_t<threads>_out.txt`, and the timings are collected in `results/benchmark_results.txt`. BEAST's own log files are written next to each XML and are overwritten by the next configuration.

### Individual Analyses

Run specific configurations directly:

```bash
# Single-threaded CPU
java -Djava.library.path=$HOME/local/lib -jar beast.jar -seed 666 -beagle_threading none -overwrite \
     ./XML/benchmark/gradient/pedv_compare.xml

# Multi-threaded CPU with OpenMP (e.g. 26 threads)
java -Djava.library.path=$HOME/local/lib -jar beast.jar -seed 666 -beagle_threading openmp -beagle_basta_threads 26 -overwrite \
     ./XML/benchmark/scaling/const_K120_n2000_basta.xml

# GPU
java -Djava.library.path=$HOME/local/lib -jar beast.jar -seed 666 -beagle_gpu -overwrite \
     ./XML/benchmark/gradient/ebov_adjoint.xml

# Sampling comparison on the GPU (run the HMC and random-walk chains from different
# working directories, because each pair writes some identically named files)
java -Djava.library.path=$HOME/local/lib -jar beast.jar -seed 666 -beagle_gpu -overwrite \
     ./XML/benchmark/sampling/HMC/pedv_HMC.xml
java -Djava.library.path=$HOME/local/lib -jar beast.jar -seed 666 -beagle_gpu -overwrite \
     ./XML/benchmark/sampling/RWMH/pedv_RWMH.xml

# Joint influenza A/H3N2 analysis on the GPU
java -Djava.library.path=$HOME/local/lib -jar beast.jar -seed 606 -beagle_gpu -overwrite \
     ./XML/analysis/RE/airCommunities_H3N2_RE.xml
```

## Dataset Information

| Dataset | Taxa | Locations | Source |
|---|---|---|---|
| DENV-1 | 287 | 10 | Nunes et al. 2014 |
| PEDV | 769 | 26 | He et al. 2022 |
| EBOV (Makona) | 1,610 | 56 | Dudas et al. 2017 |
| Influenza A/H3N2 | 1,529 | 14 | Lemey et al. 2014 |
| Simulated scaling grid | 250–2,000 | 10–120 | this study (ReMASTER; Vaughan 2024) |

The empirical XMLs contain their alignments. The simulated scaling XMLs contain the fixed genealogy and the tip demes.

## Software Availability

- BEAGLE (SCA likelihood and adjoint gradient kernels): <https://github.com/beagle-dev/beagle-lib/tree/basta_adjoint>
- BEAST X (SCA adjoint gradient and Hamiltonian Monte Carlo): <https://github.com/beast-dev/beast-mcmc/tree/basta_adjoint>

## References

- Dudas, G., Carvalho, L. M., Bedford, T., Tatem, A. J., Baele, G., Faria, N. R., Park, D. J., Ladner, J. T., Arias, A., Asogun, D., et al. *Virus genomes reveal factors that spread and sustained the Ebola epidemic.* Nature, 544:309–315, 2017.
- He, W.-T., Bollen, N., Xu, Y., Zhao, J., Dellicour, S., Yan, Z., Gong, W., Zhang, C., Zhang, L., Lu, M., et al. *Phylogeography reveals association between swine trade and the spread of porcine epidemic diarrhea virus in China and across the world.* Molecular Biology and Evolution, 39(2):msab364, 2022.
- Lemey, P., Rambaut, A., Bedford, T., Faria, N., Bielejec, F., Baele, G., Russell, C. A., Smith, D. J., Pybus, O. G., Brockmann, D., Suchard, M. A. *Unifying viral genetics and human transportation data to predict the global transmission dynamics of human influenza H3N2.* PLoS Pathogens, 10(2):e1003932, 2014.
- Magee, A. F., Holbrook, A. J., Pekar, J. E., Caviedes-Solis, I. W., Matsen IV, F. A., Baele, G., Wertheim, J. O., Ji, X., Lemey, P., Suchard, M. A. *Random-effects substitution models for phylogenetics via scalable gradient approximations.* Systematic Biology, 73(3):562–578, 2024.
- Nunes, M. R. T., Palacios, G., Faria, N. R., Sousa Jr, E. C., Pantoja, J. A., Rodrigues, S. G., Carvalho, V. L., Medeiros, D. B. A., Savji, N., Baele, G., et al. *Air travel is associated with intracontinental spread of dengue virus serotypes 1–3 in Brazil.* PLoS Neglected Tropical Diseases, 8(4):e2769, 2014.
- Shao, Y., Suchard, M. A., Rambaut, A., Ji, X., Lemey, P., Vasylyeva, T. I., Baele, G. *Parallel algorithms for phylogenetic inference under a structured coalescent approximation.* Proceedings of the National Academy of Sciences, 123(18):e2602412123, 2026.
- Vaughan, T. G. *ReMASTER: improved phylodynamic simulation for BEAST 2.7.* Bioinformatics, 40(1):btae015, 2024.
