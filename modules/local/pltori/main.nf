process PLTORI {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://blancojmskcc/pltori:0.0.1':
        'blancojmskcc/pltori:0.0.1' }"

    input:
    tuple val(meta), path(oridat)

    output:
    tuple val(meta), path("*_PyshClone_BoxPlot_PyshClon_OriginalData.pdf") , emit: bp_pdf
    tuple val(meta), path("*_PyshClone_FlowPlot_PyshClon_OriginalData.pdf"), emit: fp_pdf
    tuple val(meta), path("*_PyshClone_PairWise_PyshClon_OriginalData.pdf"), emit: pw_pdf
    path "versions.yml"                                                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    rm .command.trace || true

    mkdir .mplconfig

    export MPLCONFIGDIR=".mplconfig"

    pltori \\
        --dir_outs '.' \\
        --oridat ${oridat} \\
        --patient ${prefix} \\
        ${args}

    set +o noclobber

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pltori: "0.0.1"
    END_VERSIONS
    """
    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_PyshClone_BoxPlot_PyshClon_OriginalData.pdf
    touch ${prefix}_PyshClone_FlowPlot_PyshClon_OriginalData.pdf
    touch ${prefix}_PyshClone_PairWise_PyshClon_OriginalData.pdf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pltori: "0.0.1"
    END_VERSIONS
    """
}
