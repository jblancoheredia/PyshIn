process PREPVI_2PASS {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://blancojmskcc/prepvi2pass:1.0.0':
        'blancojmskcc/prepvi2pass:1.0.0' }"

    input:
    tuple val(meta), path(pvi_inn_tsv), path(aftpvi_edited_tsv)
    val(samples_mode)
    path(mut_file)
    path(pty_file)

    output:
    tuple val(meta), path("*_PyCloneVI_INN_2PASS.tsv"), emit: tsv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    rm .command.trace || true

    prepvi2pass \\
        --inn ${pvi_inn_tsv} \\
        --edited ${aftpvi_edited_tsv} \\
        --out ${prefix}_PyCloneVI_INN_2PASS.tsv \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        prepvi2pass: "1.0.0"
    END_VERSIONS
    """
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_PyCloneVI_INN_2PASS.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        prepvi2pass: "1.0.0"
    END_VERSIONS
    """
}
