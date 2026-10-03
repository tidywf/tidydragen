# Dragen Object

Orchestrates all DRAGEN tools
([DragenMap](https://tidywf.github.io/tidydragen/reference/DragenMap.md),
[DragenFqc](https://tidywf.github.io/tidydragen/reference/DragenFqc.md),
[DragenCov](https://tidywf.github.io/tidydragen/reference/DragenCov.md),
[DragenVar](https://tidywf.github.io/tidydragen/reference/DragenVar.md),
[DragenRna](https://tidywf.github.io/tidydragen/reference/DragenRna.md),
[DragenTso](https://tidywf.github.io/tidydragen/reference/DragenTso.md),
[DragenBcl](https://tidywf.github.io/tidydragen/reference/DragenBcl.md))
plus [Interop](https://tidywf.github.io/tidydragen/reference/Interop.md)
for convenience. A DRAGEN run exposes a different subset of files
depending on the pipeline; tools whose files are absent contribute
nothing, so a single `Dragen$run()` works across all pipelines.

## Super class

[`nemo::Workflow`](https://tidywf.github.io/nemo/reference/Workflow.html)
-\> `Dragen`

## Public fields

- `sync_exclude`:

  (`character(n)`)  
  Trailing `aws s3 sync` excludes, see
  [DRAGEN_SYNC_EXCLUDE](https://tidywf.github.io/tidydragen/reference/DRAGEN_SYNC_EXCLUDE.md).

## Methods

### Public methods

- [`Dragen$new()`](#method-Dragen-new)

Inherited methods

- [`nemo::Workflow$filter_files()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-filter_files)
- [`nemo::Workflow$get_globs()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-get_globs)
- [`nemo::Workflow$get_metadata()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-get_metadata)
- [`nemo::Workflow$get_schemas_raw()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-get_schemas_raw)
- [`nemo::Workflow$get_schemas_tidy()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-get_schemas_tidy)
- [`nemo::Workflow$get_sync_patterns()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-get_sync_patterns)
- [`nemo::Workflow$get_tbls()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-get_tbls)
- [`nemo::Workflow$get_tools()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-get_tools)
- [`nemo::Workflow$list_files()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-list_files)
- [`nemo::Workflow$print()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-print)
- [`nemo::Workflow$run()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-run)
- [`nemo::Workflow$tidy()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-tidy)
- [`nemo::Workflow$write()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-write)

------------------------------------------------------------------------

### Method `new()`

Create a new Dragen object.

#### Usage

    Dragen$new(path = NULL)

#### Arguments

- `path`:

  (`character(n)`)  
  Path(s) to DRAGEN results.

## Examples

``` r
indir <- system.file("extdata", package = "tidydragen")
odir <- tempdir()
d <- Dragen$new(indir)
d$run(output_dir = odir, format = "parquet", input_id = "run1")
(lf <- list.files(odir, pattern = "\\.parquet$", full.names = FALSE))
#>  [1] "dragenbcl_adaptercyclemetrics.parquet"           
#>  [2] "dragenbcl_adaptermetrics.parquet"                
#>  [3] "dragenbcl_demultiplexstats.parquet"              
#>  [4] "dragenbcl_demultiplextilestats.parquet"          
#>  [5] "dragenbcl_fastqlist.parquet"                     
#>  [6] "dragenbcl_indexhoppingcounts.parquet"            
#>  [7] "dragenbcl_qualitymetrics.parquet"                
#>  [8] "dragenbcl_qualitytilemetrics.parquet"            
#>  [9] "dragenbcl_runinfo.parquet"                       
#> [10] "dragenbcl_topunknownbarcodes.parquet"            
#> [11] "interop_imagingtable.parquet"                    
#> [12] "interop_imagingtable_2.parquet"                  
#> [13] "metadata.parquet"                                
#> [14] "runA_interop_indexsummarydetail.parquet"         
#> [15] "runA_interop_indexsummarymain.parquet"           
#> [16] "runA_interop_summarymain.parquet"                
#> [17] "runA_interop_summaryreadlane.parquet"            
#> [18] "sampleA_dragenfqc_posbasecontent.parquet"        
#> [19] "sampleA_dragenfqc_posbasemeanqual.parquet"       
#> [20] "sampleA_dragenfqc_posqual.parquet"               
#> [21] "sampleA_dragenfqc_readgc.parquet"                
#> [22] "sampleA_dragenfqc_readgcqual.parquet"            
#> [23] "sampleA_dragenfqc_readlen.parquet"               
#> [24] "sampleA_dragenfqc_readmeanqual.parquet"          
#> [25] "sampleA_dragenfqc_seqpos.parquet"                
#> [26] "sampleA_dragenmap_fraglenhist.parquet"           
#> [27] "sampleA_dragenmap_gcbias.parquet"                
#> [28] "sampleA_dragenmap_gcmain.parquet"                
#> [29] "sampleA_dragenmap_metrics.parquet"               
#> [30] "sampleA_dragenmap_replayconfig.parquet"          
#> [31] "sampleA_dragenmap_replaymain.parquet"            
#> [32] "sampleA_dragenmap_time.parquet"                  
#> [33] "sampleA_dragenmap_trimmer.parquet"               
#> [34] "sampleA_dragenmap_umihist.parquet"               
#> [35] "sampleA_dragenmap_umimain.parquet"               
#> [36] "sampleA_dragenrna_fusion.parquet"                
#> [37] "sampleA_dragenrna_quant.parquet"                 
#> [38] "sampleA_dragentso_exoncov.parquet"               
#> [39] "sampleA_dragentso_fusions.parquet"               
#> [40] "sampleA_dragentso_genecov.parquet"               
#> [41] "sampleA_dragentso_sarcnv.parquet"                
#> [42] "sampleA_dragentso_sarmain.parquet"               
#> [43] "sampleA_dragentso_sarqc.parquet"                 
#> [44] "sampleA_dragentso_sarqcthr.parquet"              
#> [45] "sampleA_dragentso_sarsnv.parquet"                
#> [46] "sampleA_dragentso_sarsw.parquet"                 
#> [47] "sampleA_dragentso_sarswds.parquet"               
#> [48] "sampleA_dragentso_smallvariants.parquet"         
#> [49] "sampleA_dragentso_tmbmsaf.parquet"               
#> [50] "sampleA_dragentso_tmbtrace.parquet"              
#> [51] "sampleA_dragenvar_cnv.parquet"                   
#> [52] "sampleA_dragenvar_contamination.parquet"         
#> [53] "sampleA_dragenvar_gvcf.parquet"                  
#> [54] "sampleA_dragenvar_hethom.parquet"                
#> [55] "sampleA_dragenvar_hrd.parquet"                   
#> [56] "sampleA_dragenvar_microsat.parquet"              
#> [57] "sampleA_dragenvar_nuctrans.parquet"              
#> [58] "sampleA_dragenvar_ploidymain.parquet"            
#> [59] "sampleA_dragenvar_ploidyratio.parquet"           
#> [60] "sampleA_dragenvar_ploidyvcf.parquet"             
#> [61] "sampleA_dragenvar_sv.parquet"                    
#> [62] "sampleA_dragenvar_tmb.parquet"                   
#> [63] "sampleA_dragenvar_vc.parquet"                    
#> [64] "sampleA_exon_dragencov_metricsbins.parquet"      
#> [65] "sampleA_exon_dragencov_metricscumu.parquet"      
#> [66] "sampleA_exon_dragencov_metricsmain.parquet"      
#> [67] "sampleA_target_bed_dragencov_metricsbins.parquet"
#> [68] "sampleA_target_bed_dragencov_metricscumu.parquet"
#> [69] "sampleA_target_bed_dragencov_metricsmain.parquet"
#> [70] "sampleA_umccr_dragencov_readreportbed.parquet"   
#> [71] "sampleA_umccr_dragencov_reportbedcumu.parquet"   
#> [72] "sampleA_umccr_dragencov_reportbedmain.parquet"   
#> [73] "sampleA_wgs_dragencov_contigmean.parquet"        
#> [74] "sampleA_wgs_dragencov_finehist.parquet"          
#> [75] "sampleA_wgs_dragencov_metricsbins.parquet"       
#> [76] "sampleA_wgs_dragencov_metricscumu.parquet"       
#> [77] "sampleA_wgs_dragencov_metricsmain.parquet"       
#> [78] "sampleA_wgs_normal_dragencov_contigmean.parquet" 
#> [79] "sampleA_wgs_tumor_dragencov_contigmean.parquet"  
#> [80] "sampleB_2_dragenmap_replayconfig.parquet"        
#> [81] "sampleB_2_dragenmap_replaymain.parquet"          
#> [82] "sampleB_2_dragenmap_time.parquet"                
#> [83] "sampleB_dragenmap_replayconfig.parquet"          
#> [84] "sampleB_dragenmap_replaymain.parquet"            
#> [85] "sampleB_dragenmap_time.parquet"                  
#> [86] "sampleB_dragenvar_cnv.parquet"                   
#> [87] "sampleB_dragenvar_ploidymain.parquet"            
#> [88] "sampleB_dragenvar_ploidyratio.parquet"           
#> [89] "sampleB_dragenvar_vc.parquet"                    
(pats <- d$get_sync_patterns())
#> # A tibble: 56 × 2
#>    inex  pat                       
#>    <chr> <chr>                     
#>  1 ex    *                         
#>  2 in    *.mapping_metrics.csv     
#>  3 in    *.time_metrics.csv        
#>  4 in    *.fragment_length_hist.csv
#>  5 in    *.trimmer_metrics.csv     
#>  6 in    *.umi_metrics.csv         
#>  7 in    *.gc_metrics.csv          
#>  8 in    *-replay.json             
#>  9 in    *.fastqc_metrics.csv      
#> 10 in    *.*_coverage_metrics*.csv 
#> # ℹ 46 more rows
```
