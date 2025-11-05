process PYCLONEVI_FULL {
    tag "$meta.patient"
    label "process_high"
    
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://blancojmskcc/pyclone-vi:0.1.6':
        'blancojmskcc/pyclone-vi:0.1.6' }"

    input:
    tuple val(meta), path(tsv_in)
    val(n_reiterations)
    val(max_clusters)
    val(max_iters)
    val(b_model)
    val(seed)

    output:
        tuple val(meta), path("*_PyCloneVI_OUT.tsv"), emit: tsv
        path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def prefix = task.ext.prefix ?: "${meta.patient}"
    """
    pyclone-vi fit  \\
        -i ${tsv_in} \\
        -d ${b_model} \\
        --seed ${seed} \\
        -c ${max_clusters} \\
        -r ${n_reiterations} \\
        -o ${prefix}_PC_OUT.h5 \\
        --max-iters ${max_iters} \\
        ${args}

    pyclone-vi write-results-file \\
        -i ${prefix}_PC_OUT.h5 \\
        -o ${prefix}_PyCloneVI_OUT.tsv \\
        ${args2}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        "pyclone-vi": \$(pyclone-vi --version |& sed '1!d; s/^pyclone-vi, version //')
    END_VERSIONS
    """
    stub:
    def prefix = task.ext.prefix ?: "${meta.patient}"
    """
    touch ${prefix}_PyCloneVI_OUT.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        "pyclone-vi": \$(pyclone-vi --version |& sed '1!d; s/^pyclone-vi, version //')
    END_VERSIONS
    """
}
