process PYSHCLONE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://blancojmskcc/pyshclone:2.0.0':
        'blancojmskcc/pyshclone:2.0.0' }"

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
    echo "${timepoints}"

    rm .command.trace || true

    mkdir .mplconfig

    export MPLCONFIGDIR=".mplconfig"

    export XDG_CACHE_HOME="$(mktemp -d)"

    PyshClone \\
        --outdir . \\
        --founder 1 \\
        --max_iter 3 \\
        --patient ${prefix} \\
        --enumeration exhaustive \\
        --timepoints=${timepoints} \\
        --edited_tsv ${pvi_out_eddited} \\
        ${args}

    set +o noclobber

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyshclone: 2.0.0
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
        pyshclone: 2.0.0
    END_VERSIONS
    """
}
