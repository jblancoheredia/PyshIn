//
// Subworkflow with functionality specific to the nf-core/pyshin pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                               IMPORT WORKFLOW & SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsHelp                                        } from 'plugin/nf-schema'
include { imNotification                                    } from '../../nf-core/utils_nfcore_pipeline'
include { completionEmail                                   } from '../../nf-core/utils_nfcore_pipeline'
include { paramsSummaryMap                                  } from 'plugin/nf-schema'
include { completionSummary                                 } from '../../nf-core/utils_nfcore_pipeline'
include { samplesheetToList                                 } from 'plugin/nf-schema'
include { UTILS_NFCORE_PIPELINE                             } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFSCHEMA_PLUGIN                             } from '../../nf-core/utils_nfschema_plugin'
include { UTILS_NEXTFLOW_PIPELINE                           } from '../../nf-core/utils_nextflow_pipeline'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                             SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {

    take:
    monochrome_logs  
    validate_params  
    version          
    outdir           
    input            
    nextflow_cli_args

    main:

    ch_versions = Channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    UTILS_NFSCHEMA_PLUGIN (
        workflow,
        validate_params,
        null
    )

    UTILS_NFSCHEMA_PLUGIN (
        workflow,
        validate_params,
        null
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    //
    // Create channel from input file provided through params.input
    //
    Channel
        .fromList(samplesheetToList(params.input, "${projectDir}/assets/schema_input.json"))
        .map { row ->
            def required = ['patient','sample_id','cnv_vcf','snp_csv']
            def missing  = required.findAll { !row.containsKey(it) || !row[it] }
            if (missing) throw new IllegalArgumentException("samplesheet missing: ${missing.join(', ')}")
            def meta = [ patient: row.patient as String, sample_id: row.sample_id as String ]
            def cnv  = file(row.cnv_vcf)
            def snp  = file(row.snp_csv)
            [ meta.patient, meta, cnv, snp ]
      }
      .groupTuple()
      .map { patient_id, metas, cnvs, snps ->
          [ patient_id, metas as List<Map>, cnvs as List<File>, snps as List<File> ]
      }
      .set { ch_samplesheet }

    emit:
    samplesheet = ch_samplesheet
    versions    = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                                         SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {

    take:
    email           //  string: email address
    outdir          //    path: Path to output directory where results will be published
    hook_url        //  string: hook URL for notifications
    email_on_fail   //  string: email address sent on pipeline failure
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    plaintext_email // boolean: Send plain-text email instead of HTML
//    multiqc_report  //  string: Path to MultiQC report

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
//    def multiqc_reports = multiqc_report.toList()

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
//                multiqc_reports.getVal(),
            )
        }

        completionSummary(monochrome_logs)
        if (hook_url) {
            imNotification(summary_params, hook_url)
        }
    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting"
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                                                      FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Validate channels from input samplesheet
//
def validateInputSamplesheet(input) {
    def (metas, fastqs) = input[1..2]

    // Check that multiple runs of the same sample are of the same datatype i.e. single-end / paired-end
    def endedness_ok = metas.collect{ meta -> meta.single_end }.unique().size == 1
    if (!endedness_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must be of the same datatype i.e. single-end or paired-end: ${metas[0].id}")
    }

    return [ metas[0], fastqs ]
}

//
// Generate methods description for MultiQC
//
def toolCitationText() {
    def citation_text = [
            "Tools used in the workflow included:",
            "PyClone-VI (Gillis & Roth 2020),",
            "MultiQC (Ewels et al. 2016)",
            "."
        ].join(' ').trim()
    return citation_text
}

def toolBibliographyText() {
    def reference_text = [
            "<li>Gillis S., & Roth A., (2020) PyClone-VI: scalable inference of clonal population structures using whole genome data, BMC Bioinformatics, 21, 571. doi: 10.1186/s12859-020-03919-2</li>",
            "<li>Ewels, P., Magnusson, M., Lundin, S., & Käller, M. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics , 32(19), 3047–3048. doi: /10.1093/bioinformatics/btw354</li>"
        ].join(' ').trim()
    return reference_text
}

def methodsDescriptionText(mqc_methods_yaml) {
    def meta = [:]
    meta.workflow = workflow.toMap()
    meta["manifest_map"] = workflow.manifest.toMap()
    if (meta.manifest_map.doi) {
        def temp_doi_ref = ""
        def manifest_doi = meta.manifest_map.doi.tokenize(",")
        manifest_doi.each { doi_ref ->
            temp_doi_ref += "(doi: <a href=\'https://doi.org/${doi_ref.replace("https://doi.org/", "").replace(" ", "")}\'>${doi_ref.replace("https://doi.org/", "").replace(" ", "")}</a>), "
        }
        meta["doi_text"] = temp_doi_ref.substring(0, temp_doi_ref.length() - 2)
    } else meta["doi_text"] = ""
    meta["nodoi_text"] = meta.manifest_map.doi ? "" : "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"
    meta["tool_citations"] = ""
    meta["tool_bibliography"] = ""
    def methods_text = mqc_methods_yaml.text
    def engine =  new groovy.text.SimpleTemplateEngine()
    def description_html = engine.createTemplate(methods_text).make(meta)
    return description_html.toString()
}
