process AFTPVI_2PASS {
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
    tuple val(meta), path("*_OriginalData_2PASS.tsv"), emit: ori
    tuple val(meta), path("*_EditedData_2PASS.tsv")  , emit: edi
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
        --mut_file ${mut_file} \\
        --samples_mode ${samples_mode} \\
        --isdriver_file ${isdriver_file} \\
        ${args}

    mv ${prefix}/* .

    mv ${prefix}_PyClone_EditedData.tsv ${prefix}_PyClone_EditedData_2PASS.tsv

    mv ${prefix}_PyClone_OriginalData.tsv ${prefix}_PyClone_OriginalData_2PASS.tsv

    set +o noclobber

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        aftpvi: "2.0.0"
    END_VERSIONS
    """
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_PyClone_OriginalData_2PASS.tsv
    
    touch ${prefix}_PyClone_EditedData_2PASS.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        aftpvi: "2.0.0"
    END_VERSIONS
    """
}
