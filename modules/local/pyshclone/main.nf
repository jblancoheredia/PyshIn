process PYSHCLONE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://blancojmskcc/pyshclone:1.0.0':
        'blancojmskcc/pyshclone:1.0.0' }"

    input:
    tuple val(meta), path(pvi_out_eddited)

    output:
    tuple val(meta), path("*.pdf"), emit: pdf
    tuple val(meta), path("*.tsv"), emit: tsv
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def timepoints = task.ext.timepoints ?: "${meta.timepoints}"
    """
    rm .command.trace || true
    PyshClone \\
        -@ $task.cpus \\
        -o ${prefix}.bam \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyshclone: 1.0.0
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.pdf
    touch ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyshclone: 1.0.0
    END_VERSIONS
    """
}
