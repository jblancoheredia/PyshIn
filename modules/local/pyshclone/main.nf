process PYSHCLONE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://blancojmskcc/pyshclone:4.0.0':
        'blancojmskcc/pyshclone:4.0.0' }"

    input:
    tuple val(meta), path(pvi_out_eddited)
    val(max_iter_phylo_model)
    val(enumeration_model)
    val(founder_cluster)

    output:
    tuple val(meta), path("*.pdf") , emit: pdf
    tuple val(meta), path("*.tsv") , emit: tsv
    tuple val(meta), path("*.json"), emit: json
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def tp_raw = task.ext.timepoints ?: "${meta.timepoints}"
    def timepoints = (tp_raw instanceof List)
      ? tp_raw.join(',')
      : tp_raw.toString().replace('[','').replace(']','').replaceAll(/\s+/, '')
    """
    echo "These are the timepoints: ${timepoints}"

    rm .command.trace || true

    export MPLBACKEND=Agg

    mkdir .mplconfig

    mkdir -p .cache/{fontconfig,matplotlib}

    export MPLCONFIGDIR=".mplconfig"

    export XDG_CACHE_HOME=".cache"

    PyshClone \\
        --outdir . \\
        --patient ${prefix} \\
        --founder ${founder_cluster} \\
        --timepoints="${timepoints}"  \\
        --edited_tsv ${pvi_out_eddited} \\
        --enumeration ${enumeration_model} \\
        --max_iter ${max_iter_phylo_model}  \\
        ${args}

    set +o noclobber

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyshclone: 4.0.0
    END_VERSIONS
    """
    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.pdf
    touch ${prefix}.tsv
    touch ${prefix}.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyshclone: 4.0.0
    END_VERSIONS
    """
}
