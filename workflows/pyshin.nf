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
include { AFTPVI_2PASS                                                                  } from '../modules/local/aftpvi2pass/main'
include { PREPVI_2PASS                                                                  } from '../modules/local/prepvi2pass/main'
include { PYCLONEVI_FULL                                                                } from '../modules/local/pyclonevi/full/main' 
include { PYCLONEVI_FULL    as PYCLONEVI_FULL_2PASS                                     } from '../modules/local/pyclonevi/full/main' 


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
    AFTPVI (ch_aftpvi_inn, params.isdriver_file, params.samples_mode, params.mutations_file, params.min_cluster_prob)
    ch_edited_data = AFTPVI.out.edi
    ch_original_data = AFTPVI.out.ori
    ch_versions = ch_versions.mix(AFTPVI.out.versions)

    if (params.min_cluster_prob > 0) {

        ch_prepvi2pass_inn = (ch_prepvi_tsv).join(ch_edited_data)
        //
        // RUN PRE_PYCLONE-VI 2PASS
        //
        PREPVI_2PASS (ch_prepvi2pass_inn)
        ch_prepvi2pass_tsv = PREPVI_2PASS.out.tsv
        ch_versions = ch_versions.mix(PREPVI_2PASS.out.versions)

        //
        // RUN PYCLONE-VI_FULL 2PASS
        //
        PYCLONEVI_FULL_2PASS (ch_prepvi2pass_tsv, params.n_reiterations, params.max_clusters, params.max_iters, params.b_model, params.seed)
        ch_pyclonevi2pass_tsv = PYCLONEVI_FULL_2PASS.out.tsv
        ch_versions = ch_versions.mix(PYCLONEVI_FULL_2PASS.out.versions)

        ch_aftpvi2pass_inn = (ch_prepvi2pass_tsv).join(ch_pyclonevi2pass_tsv)

        //
        // RUN AFTER_PYCLONE-VI 2PASS
        //
        AFTPVI_2PASS (ch_aftpvi2pass_inn, params.isdriver_file, params.samples_mode, params.mutations_file, params.min_cluster_prob)
        ch_edited_data2pass = AFTPVI_2PASS.out.edi
        ch_original_data2pass = AFTPVI_2PASS.out.ori
        ch_versions = ch_versions.mix(AFTPVI_2PASS.out.versions)

        //
        // RUN PLOT_ORIGINALDATA
        //
        PLTORI (ch_original_data2pass)
        ch_versions = ch_versions.mix(PLTORI.out.versions)

        //
        // RUN PYSHCLONE 
        //
        PYSHCLONE (ch_edited_data2pass, params.max_iter_phylo_model, params.enumeration_model, params.founder_cluster)
        ch_final_data = PYSHCLONE.out.tsv
        ch_final_pdfs = PYSHCLONE.out.pdf
        ch_versions = ch_versions.mix(PYSHCLONE.out.versions)

    } else {

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

    }

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
