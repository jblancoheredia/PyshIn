process AFTPVI {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://blancojmskcc/aftpvi:2.0.0':
        'blancojmskcc/aftpvi:2.0.0' }"

    input:
    tuple val(meta), path(pvi_inn), path(pvi_out)
    path(isdriver_file)
    val(samples_mode)
    path(mut_file)
    val(min_prob)
    
    output:
    tuple val(meta), path("*_OriginalData.tsv"), emit: ori
    tuple val(meta), path("*_EditedData.tsv")  , emit: edi
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    rm .command.trace || true

    mkdir .mplconfig

    export MPLCONFIGDIR=".mplconfig"

    aftpvi \\
        --dir_outs '.' \\
        --patient ${prefix} \\
        --pvi_inn ${pvi_inn} \\
        --pvi_out ${pvi_out} \\
        --min_prob ${min_prob} \\
        --mut_file ${mut_file} \\
        --samples_mode ${samples_mode} \\
        --isdriver_file ${isdriver_file} \\
        ${args}

    mv ${prefix}/* .

    set +o noclobber

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        aftpvi: "2.0.0"
    END_VERSIONS
    """
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_OriginalData.tsv
    touch ${prefix}_EditedData.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        aftpvi: "2.0.0"
    END_VERSIONS
    """
}
