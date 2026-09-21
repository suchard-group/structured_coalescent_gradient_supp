Analysis files for the adjoint gradient of the structured coalescent approximation (SCA) in `BEAST X`, with GPU support.

```
XML/
  analysis/
    RE/         influenza A/H3N2, one random effect per ordered pair of communities
    FIX/        the same model with the random effects fixed to zero
  benchmark/
    gradient/   adjoint against central finite differences (DENV-1, PEDV, EBOV)
    sampling/   HMC against random-walk sampling, genealogy fixed
      HMC/
      RWMH/
    scaling/    simulated genealogies, const_K<demes>_n<taxa>, 5 x 5 grid
    benchmark_all.sh
```

Run with `BEAST X` (v10.5.0) and `BEAGLE` from the `basta_adjoint` branches:

```bash
beast -seed 666 -beagle_gpu -overwrite XML/analysis/RE/airCommunities_H3N2_RE.xml
```

The scaling grid covers 250, 500, 1000, 1500 and 2000 tips by 10, 20, 40, 80
and 120 demes. `benchmark_all.sh` loops over the gradient and scaling XMLs at
each setting reported in the paper, CPU thread counts 1, 4, 12, 26 and 32 and
the GPU (`THREAD_COUNTS`, where 999 selects the GPU), and collects the timing
tables; set `BEAST_JAR` and `BEAGLE_LIB` at the top of the
script first.
The sampling XMLs are the long chains for the effective sample size comparison
and are run individually.

Sequence data come from the original studies: DENV-1 (Nunes et al. 2014), PEDV
(He et al. 2022), EBOV (Dudas et al. 2017) and influenza A/H3N2 (Lemey et al.
2014). The alignments are contained in the XML files.
