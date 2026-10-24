#!/usr/bin/env Rscript

suppressPackageStartupMessages(use("nemo", c("nemo_cli")))
nemo::nemo_cli(pkg = "tidydragen", descr = "✨ DRAGEN Output Tidying ✨", wf = "dragen")
