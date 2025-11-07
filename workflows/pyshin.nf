#!/usr/bin/env nextflow

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                                                        IMPORT PLUGINS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap                                                              } from 'plugin/nf-schema'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                                                        IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { AFTPVI                                                                        } from '../modules/local/aftpvi/main'
include { PLTORI                                                                        } from '../modules/local/pltori/main'
include { PREPVI                                                                        } from '../modules/local/prepvi/main'
include { MULTIQC                                                                       } from '../modules/nf-core/multiqc/main'
include { PYSHCLONE                                                                     } from '../modules/local/pyshclone/main'
include { PYCLONEVI_FULL                                                                } from '../modules/local/pyclonevi/full/main' 


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                                                     IMPORT SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMultiqc                                                          } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML                                                        } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText                                                        } from '../subworkflows/local/utils_nfcore_pyshin_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                                                      RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


workflow PYSHIN {

    take:
    ch_samplesheet
    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // RUN PRE_PYCLONE-VI
    //
    PREPVI (ch_samplesheet, params.samples_mode, params.mutations_file, params.purity_file)
    ch_prepvi_tsv = PREPVI.out.tsv
    ch_versions = ch_versions.mix(PREPVI.out.versions)

    //
    // RUN PYCLONE-VI_FULL
    //
    PYCLONEVI_FULL (ch_prepvi_tsv, params.n_reiterations, params.max_clusters, params.max_iters, params.b_model, params.seed)
    ch_pyclonevi_tsv = PYCLONEVI_FULL.out.tsv
    ch_versions = ch_versions.mix(PYCLONEVI_FULL.out.versions)

    ch_aftpvi_inn = (ch_prepvi_tsv).join(ch_pyclonevi_tsv)

    //
    // RUN AFTER_PYCLONE-VI
    //
    AFTPVI (ch_aftpvi_inn, params.isdriver_file, params.samples_mode, params.mutations_file)
    ch_edited_data = AFTPVI.out.ori
    ch_original_data = AFTPVI.out.ori
    ch_versions = ch_versions.mix(AFTPVI.out.versions)

    //
    // RUN PLOT_ORIGINALDATA
    //
    PLTORI (ch_original_data)
    ch_versions = ch_versions.mix(PLTORI.out.versions)

    //
    // RUN PYSHCLONE 
    //
    PYSHCLONE (ch_edited_data, params.max_iter_phylo_model, params.enumeration_model, params.founder_cluster)
    ch_final_data = PYSHCLONE.out.tsv
    ch_final_pdfs = PYSHCLONE.out.pdf
    ch_versions = ch_versions.mix(PYSHCLONE.out.versions)

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'pyshin_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

      emit: versions       = ch_versions

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                                                            THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
