# Dragen Object

Orchestrates all DRAGEN tools
([DragenMap](https://tidywf.github.io/tidydragen/reference/DragenMap.md),
[DragenFqc](https://tidywf.github.io/tidydragen/reference/DragenFqc.md),
[DragenCov](https://tidywf.github.io/tidydragen/reference/DragenCov.md),
[DragenVar](https://tidywf.github.io/tidydragen/reference/DragenVar.md),
[DragenRna](https://tidywf.github.io/tidydragen/reference/DragenRna.md),
[DragenTso](https://tidywf.github.io/tidydragen/reference/DragenTso.md))
over a shared results directory. A DRAGEN run exposes a different subset
of files depending on the pipeline (germline, somatic tumor-normal,
RNA); tools whose files are absent contribute nothing, so a single
`Dragen$run()` works across all pipelines.

## Super class

[`nemo::Workflow`](https://tidywf.github.io/nemo/reference/Workflow.html)
-\> `Dragen`

## Methods

### Public methods

- [`Dragen$new()`](#method-Dragen-new)

Inherited methods

- [`nemo::Workflow$filter_files()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-filter_files)
- [`nemo::Workflow$get_metadata()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-get_metadata)
- [`nemo::Workflow$get_schemas_raw()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-get_schemas_raw)
- [`nemo::Workflow$get_schemas_tidy()`](https://tidywf.github.io/nemo/reference/Workflow.html#method-get_schemas_tidy)
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
(lf <- list.files(odir, pattern = "dragen.*parquet", full.names = FALSE))
#>  [1] "sampleA_dragenfqc_posbasecontent.parquet"        
#>  [2] "sampleA_dragenfqc_posbasemeanqual.parquet"       
#>  [3] "sampleA_dragenfqc_posqual.parquet"               
#>  [4] "sampleA_dragenfqc_readgc.parquet"                
#>  [5] "sampleA_dragenfqc_readgcqual.parquet"            
#>  [6] "sampleA_dragenfqc_readlen.parquet"               
#>  [7] "sampleA_dragenfqc_readmeanqual.parquet"          
#>  [8] "sampleA_dragenfqc_seqpos.parquet"                
#>  [9] "sampleA_dragenmap_fraglenhist.parquet"           
#> [10] "sampleA_dragenmap_gcbias.parquet"                
#> [11] "sampleA_dragenmap_gcmain.parquet"                
#> [12] "sampleA_dragenmap_metrics.parquet"               
#> [13] "sampleA_dragenmap_time.parquet"                  
#> [14] "sampleA_dragenmap_trimmer.parquet"               
#> [15] "sampleA_dragenmap_umihist.parquet"               
#> [16] "sampleA_dragenmap_umimain.parquet"               
#> [17] "sampleA_dragenrna_fusion.parquet"                
#> [18] "sampleA_dragenrna_quant.parquet"                 
#> [19] "sampleA_dragentso_exoncov.parquet"               
#> [20] "sampleA_dragentso_fusions.parquet"               
#> [21] "sampleA_dragentso_genecov.parquet"               
#> [22] "sampleA_dragentso_sarcnv.parquet"                
#> [23] "sampleA_dragentso_sarinfo.parquet"               
#> [24] "sampleA_dragentso_sarqc.parquet"                 
#> [25] "sampleA_dragentso_sarsnv.parquet"                
#> [26] "sampleA_dragentso_sarsw.parquet"                 
#> [27] "sampleA_dragentso_sarswds.parquet"               
#> [28] "sampleA_dragentso_smallvariants.parquet"         
#> [29] "sampleA_dragentso_tmbmsaf.parquet"               
#> [30] "sampleA_dragentso_tmbtrace.parquet"              
#> [31] "sampleA_dragenvar_cnv.parquet"                   
#> [32] "sampleA_dragenvar_contamination.parquet"         
#> [33] "sampleA_dragenvar_gvcf.parquet"                  
#> [34] "sampleA_dragenvar_hethom.parquet"                
#> [35] "sampleA_dragenvar_hrd.parquet"                   
#> [36] "sampleA_dragenvar_microsat.parquet"              
#> [37] "sampleA_dragenvar_nuctrans.parquet"              
#> [38] "sampleA_dragenvar_ploidyratio.parquet"           
#> [39] "sampleA_dragenvar_ploidystats.parquet"           
#> [40] "sampleA_dragenvar_ploidyvcf.parquet"             
#> [41] "sampleA_dragenvar_sv.parquet"                    
#> [42] "sampleA_dragenvar_tmb.parquet"                   
#> [43] "sampleA_dragenvar_vc.parquet"                    
#> [44] "sampleA_exon_dragencov_metricsbins.parquet"      
#> [45] "sampleA_exon_dragencov_metricscumu.parquet"      
#> [46] "sampleA_exon_dragencov_metricsmain.parquet"      
#> [47] "sampleA_target_bed_dragencov_metricsbins.parquet"
#> [48] "sampleA_target_bed_dragencov_metricscumu.parquet"
#> [49] "sampleA_target_bed_dragencov_metricsmain.parquet"
#> [50] "sampleA_umccr_dragencov_readreportbed.parquet"   
#> [51] "sampleA_umccr_dragencov_reportbedcumu.parquet"   
#> [52] "sampleA_umccr_dragencov_reportbedmain.parquet"   
#> [53] "sampleA_wgs_dragencov_contigmean.parquet"        
#> [54] "sampleA_wgs_dragencov_finehist.parquet"          
#> [55] "sampleA_wgs_dragencov_metricsbins.parquet"       
#> [56] "sampleA_wgs_dragencov_metricscumu.parquet"       
#> [57] "sampleA_wgs_dragencov_metricsmain.parquet"       
#> [58] "sampleA_wgs_normal_dragencov_contigmean.parquet" 
#> [59] "sampleA_wgs_tumor_dragencov_contigmean.parquet"  
#> [60] "sampleB_dragenvar_cnv.parquet"                   
#> [61] "sampleB_dragenvar_ploidyratio.parquet"           
#> [62] "sampleB_dragenvar_ploidystats.parquet"           
#> [63] "sampleB_dragenvar_vc.parquet"                    
```
